use "pony_test"
use ".."

primitive _TestDsn
  fun apply(): String val => "psqlred"
  fun dsn(): Dsn => Dsn("DSN=" + apply())

primitive _TestSetup
  fun connect(h: TestHelper): Connection ? =>
    match Odbc.connect(_TestDsn.dsn())
    | let c: Connection => c
    | let e: ConnectError =>
      h.fail("connect: " + e.string())
      error
    end

  fun exec(conn: Connection, sql: String val, h: TestHelper) =>
    match conn.exec(sql)
    | let e: ExecError => h.fail("exec: " + e.string() + " sql: " + sql)
    end


class iso _ConnectDisconnectTest is UnitTest
  fun name(): String => "integration: connect and disconnect"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?
      conn.close()
      // Double close should be idempotent
      conn.close()
    end


class iso _ExecDdlTest is UnitTest
  fun name(): String => "integration: exec DDL returns row count"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_ddl", h)

      match conn.exec("CREATE TABLE _test_ddl (id INTEGER)")
      | let n: USize => None // some drivers return 0
      | None => None         // some return no row count
      | let e: ExecError => h.fail("create: " + e.string())
      end

      match conn.exec("INSERT INTO _test_ddl VALUES (1)")
      | let n: USize => h.assert_eq[USize](1, n)
      | None => None
      | let e: ExecError => h.fail("insert: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_ddl", h)
      conn.close()
    end


class iso _QueryRoundtripTest is UnitTest
  fun name(): String => "integration: query roundtrip for all types"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_types", h)
      _TestSetup.exec(conn,
        "CREATE TABLE _test_types (i INTEGER, b BIGINT, f DOUBLE PRECISION, t VARCHAR(64))", h)
      _TestSetup.exec(conn,
        "INSERT INTO _test_types VALUES (42, 9000000000, 3.14, 'hello world')", h)

      match conn.query("SELECT i, b, f, t FROM _test_types")
      | let cursor: Cursor =>
        match cursor.fetch()
        | let row: Row =>
          try
            // Integer
            match row.int(ColIndex(1))?
            | let v: I64 => h.assert_eq[I64](42, v)
            else h.fail("col 1 was null")
            end
            // Bigint
            match row.int(ColIndex(2))?
            | let v: I64 => h.assert_eq[I64](9000000000, v)
            else h.fail("col 2 was null")
            end
            // Float
            match row.float(ColIndex(3))?
            | let v: F64 =>
              h.assert_true((v - 3.14).abs() < 0.001,
                "float mismatch: " + v.string())
            else h.fail("col 3 was null")
            end
            // Text
            match row.text(ColIndex(4))?
            | let v: String val => h.assert_eq[String val]("hello world", v)
            else h.fail("col 4 was null")
            end
          else
            h.fail("column read error")
          end

          // Verify EndOfRows
          match cursor.fetch()
          | EndOfRows => None
          else h.fail("expected EndOfRows after single row")
          end
        | EndOfRows => h.fail("no rows returned")
        | let e: FetchError => h.fail("fetch: " + e.string())
        end
        cursor.close()
      | let e: ExecError => h.fail("query: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_types", h)
      conn.close()
    end


class iso _NullRoundtripTest is UnitTest
  fun name(): String => "integration: NULL roundtrip"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_null", h)
      _TestSetup.exec(conn,
        "CREATE TABLE _test_null (a INTEGER, b VARCHAR(32))", h)
      _TestSetup.exec(conn,
        "INSERT INTO _test_null VALUES (NULL, NULL)", h)

      match conn.query("SELECT a, b FROM _test_null")
      | let cursor: Cursor =>
        match cursor.fetch()
        | let row: Row =>
          try
            h.assert_true(row.is_null(ColIndex(1))?, "col 1 should be null")
            h.assert_true(row.is_null(ColIndex(2))?, "col 2 should be null")

            match row.int(ColIndex(1))?
            | SqlNull => None
            else h.fail("int() should return SqlNull")
            end

            match row.text(ColIndex(2))?
            | SqlNull => None
            else h.fail("text() should return SqlNull")
            end
          else
            h.fail("column read error")
          end
        | EndOfRows => h.fail("no rows")
        | let e: FetchError => h.fail("fetch: " + e.string())
        end
        cursor.close()
      | let e: ExecError => h.fail("query: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_null", h)
      conn.close()
    end


class iso _PreparedStatementTest is UnitTest
  fun name(): String => "integration: prepared statement with params"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_prep", h)
      _TestSetup.exec(conn,
        "CREATE TABLE _test_prep (id INTEGER, name VARCHAR(64))", h)

      match conn.prepare("INSERT INTO _test_prep VALUES (?, ?)")
      | let stmt: Statement =>
        // First insert
        match stmt.bind(ParamIndex(1), SqlInt(1))
        | let e: BindError => h.fail("bind1: " + e.string())
        end
        match stmt.bind(ParamIndex(2), SqlText("alice"))
        | let e: BindError => h.fail("bind2: " + e.string())
        end
        match stmt.execute_update()
        | let n: USize => h.assert_eq[USize](1, n)
        | None => None
        | let e: ExecError => h.fail("exec1: " + e.string())
        end

        // Second insert — rebind, reuse
        match stmt.bind(ParamIndex(1), SqlInt(2))
        | let e: BindError => h.fail("rebind1: " + e.string())
        end
        match stmt.bind(ParamIndex(2), SqlText("bob"))
        | let e: BindError => h.fail("rebind2: " + e.string())
        end
        match stmt.execute_update()
        | let n: USize => h.assert_eq[USize](1, n)
        | None => None
        | let e: ExecError => h.fail("exec2: " + e.string())
        end

        stmt.close()
      | let e: PrepareError => h.fail("prepare: " + e.string())
      end

      // Verify both rows exist
      match conn.query("SELECT id, name FROM _test_prep ORDER BY id")
      | let cursor: Cursor =>
        match cursor.fetch()
        | let row: Row =>
          try
            match row.int(ColIndex(1))?
            | let v: I64 => h.assert_eq[I64](1, v)
            else h.fail("row1 id null")
            end
          else h.fail("row1 read error") end
        else h.fail("no row1") end

        match cursor.fetch()
        | let row: Row =>
          try
            match row.text(ColIndex(2))?
            | let v: String val => h.assert_eq[String val]("bob", v)
            else h.fail("row2 name null")
            end
          else h.fail("row2 read error") end
        else h.fail("no row2") end

        cursor.close()
      | let e: ExecError => h.fail("verify query: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_prep", h)
      conn.close()
    end


class iso _StatementReuseTest is UnitTest
  fun name(): String => "integration: statement reuse via close_cursor"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_reuse", h)
      _TestSetup.exec(conn,
        "CREATE TABLE _test_reuse (id INTEGER, val VARCHAR(32))", h)
      _TestSetup.exec(conn, "INSERT INTO _test_reuse VALUES (1, 'one')", h)
      _TestSetup.exec(conn, "INSERT INTO _test_reuse VALUES (2, 'two')", h)

      match conn.prepare("SELECT val FROM _test_reuse WHERE id = ?")
      | let stmt: Statement =>
        // First query: id=1
        match stmt.bind(ParamIndex(1), SqlInt(1))
        | let e: BindError => h.fail("bind: " + e.string())
        end
        match stmt.execute()
        | let e: ExecError => h.fail("exec1: " + e.string())
        end
        match stmt.fetch()
        | let row: Row =>
          try
            match row.text(ColIndex(1))?
            | let v: String val => h.assert_eq[String val]("one", v)
            else h.fail("null") end
          else h.fail("read error") end
        else h.fail("no row") end
        stmt.close_cursor()

        // Second query: id=2 — reuse statement
        match stmt.bind(ParamIndex(1), SqlInt(2))
        | let e: BindError => h.fail("rebind: " + e.string())
        end
        match stmt.execute()
        | let e: ExecError => h.fail("exec2: " + e.string())
        end
        match stmt.fetch()
        | let row: Row =>
          try
            match row.text(ColIndex(1))?
            | let v: String val => h.assert_eq[String val]("two", v)
            else h.fail("null") end
          else h.fail("read error") end
        else h.fail("no row") end

        stmt.close()
      | let e: PrepareError => h.fail("prepare: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_reuse", h)
      conn.close()
    end


class iso _TransactionTest is UnitTest
  fun name(): String => "integration: transaction commit and rollback"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_tx", h)
      _TestSetup.exec(conn,
        "CREATE TABLE _test_tx (id INTEGER)", h)

      // Test commit
      match conn.begin()
      | let e: TxBeginError => h.fail("begin: " + e.string())
      end
      _TestSetup.exec(conn, "INSERT INTO _test_tx VALUES (1)", h)
      match conn.commit()
      | let e: TxCommitError => h.fail("commit: " + e.string())
      end

      // Verify committed
      match conn.query("SELECT COUNT(*) FROM _test_tx")
      | let c: Cursor =>
        match c.fetch()
        | let row: Row =>
          try
            match row.int(ColIndex(1))?
            | let v: I64 => h.assert_eq[I64](1, v)
            else h.fail("count null") end
          else h.fail("read") end
        else h.fail("no row") end
        c.close()
      | let e: ExecError => h.fail("count query: " + e.string())
      end

      // Test rollback
      match conn.begin()
      | let e: TxBeginError => h.fail("begin2: " + e.string())
      end
      _TestSetup.exec(conn, "INSERT INTO _test_tx VALUES (2)", h)
      match conn.rollback()
      | let e: TxRollbackError => h.fail("rollback: " + e.string())
      end

      // Verify rolled back — still just 1 row
      match conn.query("SELECT COUNT(*) FROM _test_tx")
      | let c: Cursor =>
        match c.fetch()
        | let row: Row =>
          try
            match row.int(ColIndex(1))?
            | let v: I64 => h.assert_eq[I64](1, v, "should still be 1 after rollback")
            else h.fail("count null") end
          else h.fail("read") end
        else h.fail("no row") end
        c.close()
      | let e: ExecError => h.fail("count query2: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_tx", h)
      conn.close()
    end


class iso _ErrorPathsTest is UnitTest
  fun name(): String => "integration: error paths"

  fun apply(h: TestHelper) =>
    // Bad DSN
    match Odbc.connect(Dsn("DSN=psqlred_baduser"))
    | let _: Connection => h.fail("should not connect with bad user")
    | let e: ConnectError =>
      // Verify error kind
      match e.kind()
      | DriverConnectFailed => None
      else h.fail("expected DriverConnectFailed")
      end
      // Verify string() is redacted
      let s: String val = e.string()
      h.assert_false(s.contains("postgres"),
        "error string should not contain password")
    end

    // Bad SQL
    try
      let conn = _TestSetup.connect(h)?
      match conn.exec("THIS IS NOT VALID SQL")
      | let e: ExecError =>
        match e.kind()
        | SyntaxError => None
        | QueryError => None // some drivers classify differently
        else h.fail("expected SyntaxError or QueryError")
        end
      else
        h.fail("bad SQL should have errored")
      end

      // Exec on closed connection
      conn.close()
      match conn.exec("SELECT 1")
      | let e: ExecError =>
        match e.kind()
        | ConnectionClosed => None
        else h.fail("expected ConnectionClosed")
        end
      else
        h.fail("exec on closed conn should error")
      end
    end


class iso _DoubleCloseTest is UnitTest
  fun name(): String => "integration: double close is idempotent"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?

      match conn.prepare("SELECT 1")
      | let stmt: Statement =>
        stmt.close()
        stmt.close() // should be no-op

        // Operations after close should return errors
        match stmt.execute()
        | let e: ExecError =>
          match e.kind()
          | StatementClosed => None
          else h.fail("expected StatementClosed")
          end
        else
          h.fail("execute after close should error")
        end
      | let e: PrepareError => h.fail("prepare: " + e.string())
      end

      conn.close()
      conn.close() // should be no-op

      // Transactions after close
      match conn.begin()
      | let e: TxBeginError => None // expected
      else h.fail("begin after close should error")
      end
    end


class iso _CursorValuesTest is UnitTest
  fun name(): String => "integration: cursor.values() iterator"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_iter", h)
      _TestSetup.exec(conn,
        "CREATE TABLE _test_iter (id INTEGER, name VARCHAR(32))", h)
      _TestSetup.exec(conn, "INSERT INTO _test_iter VALUES (1, 'one')", h)
      _TestSetup.exec(conn, "INSERT INTO _test_iter VALUES (2, 'two')", h)
      _TestSetup.exec(conn, "INSERT INTO _test_iter VALUES (3, 'three')", h)

      match conn.query("SELECT id, name FROM _test_iter ORDER BY id")
      | let cursor: Cursor =>
        var count: USize = 0
        for row in cursor.values() do
          count = count + 1
          try
            match row.int(ColIndex(1))?
            | let v: I64 => h.assert_eq[I64](count.i64(), v)
            else h.fail("null id")
            end
          else
            h.fail("column read error")
          end
        end
        h.assert_eq[USize](3, count, "expected 3 rows from iterator")
        cursor.close()
      | let e: ExecError => h.fail("query: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_iter", h)
      conn.close()
    end


class iso _StatementValuesTest is UnitTest
  fun name(): String => "integration: statement.values() iterator"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_siter", h)
      _TestSetup.exec(conn,
        "CREATE TABLE _test_siter (id INTEGER)", h)
      _TestSetup.exec(conn, "INSERT INTO _test_siter VALUES (10)", h)
      _TestSetup.exec(conn, "INSERT INTO _test_siter VALUES (20)", h)

      match conn.prepare("SELECT id FROM _test_siter WHERE id > ? ORDER BY id")
      | let stmt: Statement =>
        match stmt.bind(ParamIndex(1), SqlInt(5))
        | let e: BindError => h.fail("bind: " + e.string())
        end
        match stmt.execute()
        | let e: ExecError => h.fail("exec: " + e.string())
        end

        var total: I64 = 0
        for row in stmt.values() do
          try
            match row.int(ColIndex(1))?
            | let v: I64 => total = total + v
            else h.fail("null")
            end
          else
            h.fail("read error")
          end
        end
        h.assert_eq[I64](30, total, "expected 10+20=30")

        stmt.close()
      | let e: PrepareError => h.fail("prepare: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_siter", h)
      conn.close()
    end
