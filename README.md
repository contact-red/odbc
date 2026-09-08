# odbc

Pony wrapper for unixODBC. Connects to any ODBC data source and returns typed, immutable `Row` snapshots with `val` reference capability — safe to hold across fetches and send between actors. Error diagnostics are redacted by default so connection strings and credentials never leak into logs.

## Status

odbc is beta-level software that will change frequently. Expect breaking changes. That said, you should feel comfortable using it in your projects.

## Installation

* Install [corral](https://github.com/ponylang/corral)
* `corral add github.com/contact-red/odbc.git --version 0.1.1`
* `corral fetch` to fetch your dependencies
* `use "odbc"` to include this package
* `corral run -- ponyc` to compile your application

## Dependencies

Requires unixODBC (`libodbc`) and at least one ODBC driver installed on the system. On Debian/Ubuntu:

```sh
apt-get install unixodbc unixodbc-dev
```

On macOS:

```sh
brew install unixodbc
```

Configure your data source in `/etc/odbc.ini` (system) or `~/.odbc.ini` (user). See your driver's documentation for connection string format.

## Tested Drivers

Every PR runs the full test suite against real databases in CI:

| Driver | Database | Column types tested |
|--------|----------|---------------------|
| [psqlODBC](https://odbc.postgresql.org/) | PostgreSQL 14 | INTEGER, DOUBLE PRECISION, VARCHAR, TEXT, BOOLEAN, DATE, TIME, TIMESTAMP, NUMERIC, BYTEA |
| [MariaDB ODBC Connector](https://mariadb.com/kb/en/mariadb-connector-odbc/) | MariaDB (latest) | INTEGER, DOUBLE, VARCHAR, LONGTEXT, TINYINT(1), DATE, TIME, TIMESTAMP, DECIMAL, VARBINARY, LONGBLOB |

## Usage

### Connect and query

```pony
use "odbc"

actor Main
  new create(env: Env) =>
    match Odbc.connect(Dsn("DSN=mydb"))
    | let conn: Connection =>
      match conn.query("SELECT id, name, price FROM products")
      | let cursor: Cursor =>
        for result in cursor.values() do
          match result
          | let row: Row =>
            try
              let id =
                match row.int(ColIndex(1))?
                | let v: I64 => v.string()
                | SqlNull => "NULL"
                end
              let name =
                match row.text(ColIndex(2))?
                | let v: String val => v
                | SqlNull => "NULL"
                end
              env.out.print(id + ": " + name)
            end
          | let e: FetchError =>
            env.err.print(e.string())
          end
        end
        cursor.close()
      | let e: ExecError =>
        env.err.print(e.string())
      end
      conn.close()
    | let e: ConnectError =>
      env.err.print(e.string())
    end
```

Each `Row` is `val` — it can be stored, compared, or sent to another actor without copying. Column indices are 1-based, matching ODBC convention.

### Prepared statements

Bind typed parameters to `?` placeholders. `Statement` is reusable: bind new values and re-execute without re-preparing.

```pony
match conn.prepare("INSERT INTO products VALUES (?, ?, ?)")
| let stmt: Statement =>
  stmt.bind(ParamIndex(1), SqlInteger(42))
  stmt.bind(ParamIndex(2), SqlText("widget"))
  stmt.bind(ParamIndex(3), SqlFloat(9.99))
  match stmt.execute_update()
  | let n: USize => env.out.print("inserted " + n.string())
  | let e: ExecError => env.err.print(e.string())
  end
  stmt.close()
| let e: PrepareError =>
  env.err.print(e.string())
end
```

### Transactions

```pony
conn.begin_p()?
conn.exec_p("INSERT INTO ledger VALUES (1, 100)")?
conn.exec_p("INSERT INTO ledger VALUES (2, -100)")?
conn.commit_p()?
```

`begin()` disables autocommit, `commit()` commits and re-enables it, `rollback()` rolls back and re-enables it. Closing a connection while in a transaction auto-rolls back.

### Partial API

Every operation has both a union-returning variant (`exec`, `query`, `prepare`, `bind`, `begin`, `commit`, `rollback`) and a partial variant with a `_p` suffix (`exec_p`, `query_p`, `prepare_p`, `bind_p`, `begin_p`, `commit_p`, `rollback_p`). The partial variants raise `error` on failure, enabling `try`/`else` chaining:

```pony
try
  let conn = Odbc.connect(Dsn("DSN=mydb")) as Connection
  conn.exec_p("DROP TABLE IF EXISTS t")?
  conn.exec_p("CREATE TABLE t (id INTEGER, label VARCHAR(32))")?
  conn
    .> begin_p()?
    .> exec_p("INSERT INTO t VALUES (1, 'alpha')")?
    .> exec_p("INSERT INTO t VALUES (2, 'bravo')")?
    .> commit_p()?
  conn.close()
else
  env.err.print("something failed")
end
```

### DbSession actor

`DbSession` wraps a `Connection` in an actor, serializing operations through its mailbox and returning results via promises:

```pony
use "promises"
use "odbc"

let db = DbSession(Dsn("DSN=mydb"))
let p = Promise[(Array[Row val] val | ExecError)]
db.query("SELECT id, name FROM products", p)
p.next[None]({(result) =>
  match result
  | let rows: Array[Row val] val =>
    for row in rows.values() do
      // each Row is val, safe to use here
    end
  | let e: ExecError =>
    env.err.print(e.string())
  end
})
```

### Statement metadata

After preparing a statement, `parameter_types()` and `column_types()` return the SQL types the driver reports for each `?` placeholder and each result column, without executing the statement:

```pony
match conn.prepare("SELECT id, name FROM products WHERE price > ?")
| let stmt: Statement =>
  match stmt.parameter_types()
  | let tags: Array[SqlTypeTag] val =>
    for t in tags.values() do
      env.out.print(t.string())  // e.g. "Float"
    end
  end
  match stmt.column_types()
  | let cols: Array[ColumnMeta] val =>
    for col in cols.values() do
      env.out.print(col.string())  // e.g. "id: Integer (not null)"
    end
  end
  stmt.close()
end
```

### Cross-actor cancellation

Long-running queries can be cancelled from another actor via `CancelToken`:

```pony
let token = cursor.cancel_token()
// send token to a supervisor actor...

// in the supervisor, on timeout:
token.cancel()
// the blocked SQLFetch returns ExecError with SQLSTATE HY008
```

### Options

`OdbcOptions` controls per-connection behavior. Pass it to `Odbc.connect()`:

* `validate_utf8` (default `true`): validate text column data as UTF-8; invalid data returns `FetchError(InvalidUtf8)` instead of silently producing a corrupt `String`
* `max_column_bytes` (default 16 MiB): upper bound on bytes read per column; columns exceeding this return `FetchError(ColumnTooLarge)`

## Data Types

### Supported ODBC types

Every ODBC SQL type below is mapped to a typed `SqlValue`. The `Row` accessor column shows which method to call on a `Row` to read the value. All accessors return `(T | SqlNull)` and raise `error` on type mismatch or out-of-range index.

| ODBC SQL type | SqlValue | Row accessor | Pony value type |
|---------------|----------|--------------|-----------------|
| SQL_BIT | `SqlBool` | `bool()` | `Bool` |
| SQL_TINYINT | `SqlTinyInt` | `int()` | `I8` (widened to `I64`) |
| SQL_SMALLINT | `SqlSmallInt` | `int()` | `I16` (widened to `I64`) |
| SQL_INTEGER | `SqlInteger` | `int()` | `I32` (widened to `I64`) |
| SQL_BIGINT | `SqlBigInt` | `int()` | `I64` |
| SQL_REAL | `SqlFloat` | `float()` | `F64` |
| SQL_FLOAT | `SqlFloat` | `float()` | `F64` |
| SQL_DOUBLE | `SqlFloat` | `float()` | `F64` |
| SQL_CHAR | `SqlText` | `text()` | `String val` |
| SQL_VARCHAR | `SqlText` | `text()` | `String val` |
| SQL_LONGVARCHAR | `SqlText` | `text()` | `String val` |
| SQL_NUMERIC | `SqlDecimal` | `decimal()` | `String val` (exact representation) |
| SQL_DECIMAL | `SqlDecimal` | `decimal()` | `String val` (exact representation) |
| SQL_TYPE_DATE | `SqlDate` | `date()` | year: `I16`, month: `U16`, day: `U16` |
| SQL_TYPE_TIME | `SqlTime` | `time()` | hour: `U16`, minute: `U16`, second: `U16` |
| SQL_TYPE_TIMESTAMP | `SqlTimestamp` | `timestamp()` | year through nanosecond fields |
| SQL_BINARY | `SqlBinary` | `binary()` | `Array[U8] val` |
| SQL_VARBINARY | `SqlBinary` | `binary()` | `Array[U8] val` |
| SQL_LONGVARBINARY | `SqlBinary` | `binary()` | `Array[U8] val` |

The `int()` accessor accepts any of the four integer types and widens to `I64`. The `bool()` accessor accepts `SqlBool`, any integer type (0 = false, nonzero = true), and text representations (`"true"`, `"false"`, `"t"`, `"f"`, `"1"`, `"0"`) to handle drivers that report boolean columns as SMALLINT or CHAR.

### Driver type mapping

How common SQL column types in each tested driver map to ODBC types and `SqlValue`:

| PostgreSQL type | MariaDB type | ODBC SQL type | SqlValue |
|-----------------|--------------|---------------|----------|
| `BOOLEAN` | `TINYINT(1)` | SQL_BIT / SQL_TINYINT | `SqlBool` / `SqlTinyInt` |
| `SMALLINT` | `SMALLINT` | SQL_SMALLINT | `SqlSmallInt` |
| `INTEGER` | `INT` | SQL_INTEGER | `SqlInteger` |
| `BIGINT` | `BIGINT` | SQL_BIGINT | `SqlBigInt` |
| `REAL` | `FLOAT` | SQL_REAL | `SqlFloat` |
| `DOUBLE PRECISION` | `DOUBLE` | SQL_DOUBLE | `SqlFloat` |
| `VARCHAR(n)` | `VARCHAR(n)` | SQL_VARCHAR | `SqlText` |
| `TEXT` | `LONGTEXT` | SQL_LONGVARCHAR | `SqlText` |
| `NUMERIC(p,s)` | `DECIMAL(p,s)` | SQL_NUMERIC / SQL_DECIMAL | `SqlDecimal` |
| `DATE` | `DATE` | SQL_TYPE_DATE | `SqlDate` |
| `TIME` | `TIME` | SQL_TYPE_TIME | `SqlTime` |
| `TIMESTAMP` | `TIMESTAMP` | SQL_TYPE_TIMESTAMP | `SqlTimestamp` |
| `BYTEA` | `VARBINARY(n)` | SQL_BINARY / SQL_VARBINARY | `SqlBinary` |
| `BYTEA` | `LONGBLOB` | SQL_LONGVARBINARY | `SqlBinary` |

### Unsupported ODBC types

Any SQL type not in the table above (SQL_WCHAR, SQL_WVARCHAR, SQL_GUID, etc.) is returned as `SqlRaw` — an escape hatch carrying the raw bytes, the SQL type code, and the byte-length indicator. `SqlRaw` round-trips through prepared statements by binding the bytes back as `SQL_C_BINARY` with the original SQL type code.

See the [`examples/`](examples/) directory for complete runnable programs.

## Documentation

* API reference: [https://odbc.contact.red/](https://odbc.contact.red/)
* Tutorial: [https://odbc-tutorial.contact.red/](https://odbc-tutorial.contact.red/)
