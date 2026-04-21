use "pony_test"
use "promises"
use ".."

primitive _TestDsn
  fun apply(h: TestHelper): String val =>
    let vars = h.env.vars
    var i: USize = 0
    while i < vars.size() do
      try
        let v = vars(i)?
        if v.substring(0, 14) == "ODBC_TEST_DSN=" then
          return v.substring(14)
        end
      end
      i = i + 1
    end
    "psqlred"

  fun dsn(h: TestHelper): Dsn =>
    Dsn("DSN=" + apply(h))

primitive _TestSetup
  fun connect(h: TestHelper): Connection ? =>
    match \exhaustive\ Odbc.connect(_TestDsn.dsn(h))
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
      _TestSetup.connect(h)?
        .> close()
        .> close()
    end

class iso _ExecDdlTest is UnitTest
  fun name(): String => "integration: exec DDL returns row count"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_ddl", h)

      match \exhaustive\ conn.exec("CREATE TABLE _test_ddl (id INTEGER)")
      | let n: USize => None // some drivers return 0
      | NoRowCount => None    // some return no row count
      | let e: ExecError => h.fail("create: " + e.string())
      end

      match \exhaustive\ conn.exec("INSERT INTO _test_ddl VALUES (1)")
      | let n: USize => h.assert_eq[USize](1, n)
      | NoRowCount => None
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
      let ct = "CREATE TABLE _test_types"
        + " (i INTEGER, b BIGINT,"
        + " f DOUBLE PRECISION, t VARCHAR(64))"
      _TestSetup.exec(conn, ct, h)
      let ins = "INSERT INTO _test_types VALUES"
        + " (42, 9000000000, 3.14, 'hello world')"
      _TestSetup.exec(conn, ins, h)

      match \exhaustive\ conn.query("SELECT i, b, f, t FROM _test_types")
      | let cursor: Cursor =>
        match \exhaustive\ cursor.fetch()
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
              h.assert_true(
                (v - 3.14).abs() < 0.001,
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
      _TestSetup.exec(
        conn, "CREATE TABLE _test_null (a INTEGER, b VARCHAR(32))", h)
      _TestSetup.exec(
        conn, "INSERT INTO _test_null VALUES (NULL, NULL)", h)

      match \exhaustive\ conn.query("SELECT a, b FROM _test_null")
      | let cursor: Cursor =>
        match \exhaustive\ cursor.fetch()
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
      _TestSetup.exec(
        conn, "CREATE TABLE _test_prep (id INTEGER, name VARCHAR(64))", h)

      match \exhaustive\ conn.prepare("INSERT INTO _test_prep VALUES (?, ?)")
      | let stmt: Statement =>
        // First insert
        match stmt.bind(ParamIndex(1), SqlInteger(1))
        | let e: BindError => h.fail("bind1: " + e.string())
        end
        match stmt.bind(ParamIndex(2), SqlText("alice"))
        | let e: BindError => h.fail("bind2: " + e.string())
        end
        match \exhaustive\ stmt.execute_update()
        | let n: USize => h.assert_eq[USize](1, n)
        | NoRowCount => None
        | let e: ExecError => h.fail("exec1: " + e.string())
        end

        // Second insert — rebind, reuse
        match stmt.bind(ParamIndex(1), SqlInteger(2))
        | let e: BindError => h.fail("rebind1: " + e.string())
        end
        match stmt.bind(ParamIndex(2), SqlText("bob"))
        | let e: BindError => h.fail("rebind2: " + e.string())
        end
        match \exhaustive\ stmt.execute_update()
        | let n: USize => h.assert_eq[USize](1, n)
        | NoRowCount => None
        | let e: ExecError => h.fail("exec2: " + e.string())
        end

        stmt.close()
      | let e: PrepareError => h.fail("prepare: " + e.string())
      end

      // Verify both rows exist
      match \exhaustive\
        conn.query("SELECT id, name FROM _test_prep ORDER BY id")
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
      _TestSetup.exec(
        conn, "CREATE TABLE _test_reuse (id INTEGER, val VARCHAR(32))", h)
      _TestSetup.exec(conn, "INSERT INTO _test_reuse VALUES (1, 'one')", h)
      _TestSetup.exec(conn, "INSERT INTO _test_reuse VALUES (2, 'two')", h)

      match \exhaustive\
        conn.prepare("SELECT val FROM _test_reuse WHERE id = ?")
      | let stmt: Statement =>
        // First query: id=1
        match stmt.bind(ParamIndex(1), SqlInteger(1))
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
        match stmt.bind(ParamIndex(1), SqlInteger(2))
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
      _TestSetup.exec(
        conn, "CREATE TABLE _test_tx (id INTEGER)", h)

      // Test commit
      match conn.begin()
      | let e: TxBeginError => h.fail("begin: " + e.string())
      end
      _TestSetup.exec(conn, "INSERT INTO _test_tx VALUES (1)", h)
      match conn.commit()
      | let e: TxCommitError => h.fail("commit: " + e.string())
      end

      // Verify committed
      match \exhaustive\ conn.query("SELECT COUNT(*) FROM _test_tx")
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
      match \exhaustive\ conn.query("SELECT COUNT(*) FROM _test_tx")
      | let c: Cursor =>
        match c.fetch()
        | let row: Row =>
          try
            match row.int(ColIndex(1))?
            | let v: I64 =>
              h.assert_eq[I64](
                1,
                v,
                "should still be 1 after rollback")
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
    match \exhaustive\ Odbc.connect(Dsn("DSN=psqlred_baduser"))
    | let _: Connection => h.fail("should not connect with bad user")
    | let e: ConnectError =>
      // Verify error kind
      match e.kind()
      | DriverConnectFailed => None
      else h.fail("expected DriverConnectFailed")
      end
      // Verify string() is redacted
      let s: String val = e.string()
      h.assert_false(
        s.contains("postgres"),
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

      match \exhaustive\ conn.prepare("SELECT 1")
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
      _TestSetup.exec(
        conn, "CREATE TABLE _test_iter (id INTEGER, name VARCHAR(32))", h)
      _TestSetup.exec(conn, "INSERT INTO _test_iter VALUES (1, 'one')", h)
      _TestSetup.exec(conn, "INSERT INTO _test_iter VALUES (2, 'two')", h)
      _TestSetup.exec(conn, "INSERT INTO _test_iter VALUES (3, 'three')", h)

      match \exhaustive\
        conn.query("SELECT id, name FROM _test_iter ORDER BY id")
      | let cursor: Cursor =>
        var count: USize = 0
        for result in cursor.values() do
          match \exhaustive\ result
          | let row: Row =>
            count = count + 1
            try
              match row.int(ColIndex(1))?
              | let v: I64 => h.assert_eq[I64](count.i64(), v)
              else h.fail("null id")
              end
            else
              h.fail("column read error")
            end
          | let e: FetchError =>
            h.fail("fetch error: " + e.string())
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
      _TestSetup.exec(
        conn, "CREATE TABLE _test_siter (id INTEGER)", h)
      _TestSetup.exec(conn, "INSERT INTO _test_siter VALUES (10)", h)
      _TestSetup.exec(conn, "INSERT INTO _test_siter VALUES (20)", h)

      match \exhaustive\
        conn.prepare("SELECT id FROM _test_siter WHERE id > ? ORDER BY id")
      | let stmt: Statement =>
        match stmt.bind(ParamIndex(1), SqlInteger(5))
        | let e: BindError => h.fail("bind: " + e.string())
        end
        match stmt.execute()
        | let e: ExecError => h.fail("exec: " + e.string())
        end

        var total: I64 = 0
        for result in stmt.values() do
          match \exhaustive\ result
          | let row: Row =>
            try
              match row.int(ColIndex(1))?
              | let v: I64 => total = total + v
              else h.fail("null")
              end
            else
              h.fail("read error")
            end
          | let e: FetchError =>
            h.fail("fetch error: " + e.string())
          end
        end
        h.assert_eq[I64](30, total, "expected 10+20=30")

        stmt.close()
      | let e: PrepareError => h.fail("prepare: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_siter", h)
      conn.close()
    end

class iso _DateTimeTypesTest is UnitTest
  fun name(): String => "integration: date/time/timestamp types"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_dt", h)
      _TestSetup.exec(
        conn, "CREATE TABLE _test_dt (d DATE, t TIME, ts TIMESTAMP)", h)
      let dt_ins = "INSERT INTO _test_dt VALUES"
        + " ('2025-06-15', '14:30:45',"
        + " '2025-06-15 14:30:45')"
      _TestSetup.exec(conn, dt_ins, h)

      match \exhaustive\ conn.query("SELECT d, t, ts FROM _test_dt")
      | let cursor: Cursor =>
        match \exhaustive\ cursor.fetch()
        | let row: Row =>
          try
            match \exhaustive\ row.date(ColIndex(1))?
            | let d: SqlDate =>
              h.assert_eq[I16](2025, d.year)
              h.assert_eq[U16](6, d.month)
              h.assert_eq[U16](15, d.day)
            | SqlNull => h.fail("date was null")
            end

            match \exhaustive\ row.time(ColIndex(2))?
            | let t: SqlTime =>
              h.assert_eq[U16](14, t.hour)
              h.assert_eq[U16](30, t.minute)
              h.assert_eq[U16](45, t.second)
            | SqlNull => h.fail("time was null")
            end

            match \exhaustive\ row.timestamp(ColIndex(3))?
            | let ts: SqlTimestamp =>
              h.assert_eq[I16](2025, ts.year)
              h.assert_eq[U16](6, ts.month)
              h.assert_eq[U16](15, ts.day)
              h.assert_eq[U16](14, ts.hour)
              h.assert_eq[U16](30, ts.minute)
              h.assert_eq[U16](45, ts.second)
            | SqlNull => h.fail("timestamp was null")
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

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_dt", h)
      conn.close()
    end

class iso _DecimalTypesTest is UnitTest
  fun name(): String => "integration: decimal/numeric types"

  fun apply(h: TestHelper) =>
    let profile = _TestDriver(h)
    if not profile.has_decimal then
      h.log("skipped: " + profile.name + " lacks decimal support")
      return
    end
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_dec", h)
      let dec_ct = "CREATE TABLE _test_dec"
        + " (price NUMERIC(10,2),"
        + " amount DECIMAL(15,4))"
      _TestSetup.exec(conn, dec_ct, h)
      _TestSetup.exec(
        conn, "INSERT INTO _test_dec VALUES (123.45, 9876543.2100)", h)

      match \exhaustive\ conn.query("SELECT price, amount FROM _test_dec")
      | let cursor: Cursor =>
        match \exhaustive\ cursor.fetch()
        | let row: Row =>
          try
            match \exhaustive\ row.decimal(ColIndex(1))?
            | let d: SqlDecimal =>
              h.assert_true(
                d.value.contains("123.45"),
                "expected 123.45 in: " + d.value)
            | SqlNull => h.fail("price was null")
            end

            match \exhaustive\ row.decimal(ColIndex(2))?
            | let d: SqlDecimal =>
              h.assert_true(
                d.value.contains("9876543.21"),
                "expected 9876543.21 in: " + d.value)
            | SqlNull => h.fail("amount was null")
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

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_dec", h)
      conn.close()
    end

class iso _FetchIntoTest is UnitTest
  fun name(): String => "integration: fetch_into reuses MutableRow"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_fi", h)
      _TestSetup.exec(
        conn, "CREATE TABLE _test_fi (id INTEGER, name VARCHAR(32))", h)
      _TestSetup.exec(conn, "INSERT INTO _test_fi VALUES (1, 'one')", h)
      _TestSetup.exec(conn, "INSERT INTO _test_fi VALUES (2, 'two')", h)
      _TestSetup.exec(conn, "INSERT INTO _test_fi VALUES (3, 'three')", h)

      match \exhaustive\ conn.query("SELECT id, name FROM _test_fi ORDER BY id")
      | let cursor: Cursor =>
        let row = MutableRow
        var count: USize = 0

        while true do
          match \exhaustive\ cursor.fetch_into(row)
          | let r: MutableRow =>
            count = count + 1
            try
              match r.int(ColIndex(1))?
              | let v: I64 => h.assert_eq[I64](count.i64(), v)
              else h.fail("null id")
              end
            else
              h.fail("column read error")
            end
          | EndOfRows => break
          | let e: FetchError => h.fail("fetch: " + e.string()); break
          end
        end

        h.assert_eq[USize](3, count, "expected 3 rows")
        // Verify the row still holds the last fetched data
        try
          match row.text(ColIndex(2))?
          | let v: String val => h.assert_eq[String val]("three", v)
          else h.fail("last row name was null")
          end
        else
          h.fail("last row read error")
        end

        cursor.close()
      | let e: ExecError => h.fail("query: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_fi", h)
      conn.close()
    end

class iso _PartialFunctionTest is UnitTest
  fun name(): String => "integration: partial function variants"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?

      // Chain DDL with try/else
      try
        conn.exec_p("DROP TABLE IF EXISTS _test_pf")?
        conn.exec_p("CREATE TABLE _test_pf (id INTEGER, name VARCHAR(32))")?
        conn.exec_p("INSERT INTO _test_pf VALUES (1, 'alice')")?
        conn.exec_p("INSERT INTO _test_pf VALUES (2, 'bob')")?
      else
        h.fail("DDL chain failed")
        conn.close()
        return
      end

      // Prepared statement with partial variants
      try
        let stmt =
          conn.prepare_p(
            "INSERT INTO _test_pf VALUES (?, ?)")?
        stmt
          .> bind_p(ParamIndex(1), SqlInteger(3))?
          .> bind_p(ParamIndex(2), SqlText("carol"))?
          .> execute_update_p()?

        stmt.bind_p(ParamIndex(1), SqlInteger(4))?
        stmt.bind_p(ParamIndex(2), SqlText("dave"))?
        stmt.execute_update_p()?
        stmt.close()
      else
        h.fail("prepared chain failed")
      end

      // Transaction with partial variants
      try
        conn.begin_p()?
        conn.exec_p("INSERT INTO _test_pf VALUES (5, 'eve')")?
        conn.commit_p()?
      else
        h.fail("transaction chain failed")
      end

      // Verify all 5 rows
      try
        let cursor = conn.query_p("SELECT COUNT(*) FROM _test_pf")?
        for result in cursor.values() do
          match \exhaustive\ result
          | let row: Row =>
            try
              match row.int(ColIndex(1))?
              | let v: I64 => h.assert_eq[I64](5, v)
              else h.fail("null count")
              end
            else
              h.fail("count read error")
            end
          | let e: FetchError =>
            h.fail("fetch error: " + e.string())
          end
        end
        cursor.close()
      else
        h.fail("count query failed")
      end

      // Verify bad SQL raises error in partial variant
      try
        conn.exec_p("THIS IS NOT VALID SQL")?
        h.fail("bad SQL should have raised error")
      end

      conn.exec_p("DROP TABLE IF EXISTS _test_pf")?
      conn.close()
    end

class iso _BindDateTimeDecimalTest is UnitTest
  fun name(): String => "integration: bind date/time/timestamp/decimal params"

  fun apply(h: TestHelper) =>
    let profile = _TestDriver(h)
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_bind_dt", h)
      let bind_ct =
        if profile.has_decimal then
          "CREATE TABLE _test_bind_dt"
            + " (d DATE, t TIME, ts TIMESTAMP, dv NUMERIC(10,2))"
        else
          "CREATE TABLE _test_bind_dt"
            + " (d DATE, t TIME, ts TIMESTAMP)"
        end
      _TestSetup.exec(conn, bind_ct, h)

      let ins_sql =
        if profile.has_decimal then
          "INSERT INTO _test_bind_dt VALUES (?, ?, ?, ?)"
        else
          "INSERT INTO _test_bind_dt VALUES (?, ?, ?)"
        end
      match \exhaustive\ conn.prepare(ins_sql)
      | let stmt: Statement =>
        match stmt.bind(ParamIndex(1), SqlDate(2025, 6, 15))
        | let e: BindError => h.fail("bind date: " + e.string())
        end
        match stmt.bind(ParamIndex(2), SqlTime(14, 30, 45))
        | let e: BindError => h.fail("bind time: " + e.string())
        end
        let ts = SqlTimestamp(2025, 6, 15, 14, 30, 45, 0)
        match stmt.bind(ParamIndex(3), ts)
        | let e: BindError => h.fail("bind timestamp: " + e.string())
        end
        if profile.has_decimal then
          match stmt.bind(ParamIndex(4), SqlDecimal("123.45"))
          | let e: BindError => h.fail("bind decimal: " + e.string())
          end
        end
        match \exhaustive\ stmt.execute_update()
        | let n: USize => h.assert_eq[USize](1, n)
        | NoRowCount => None
        | let e: ExecError => h.fail("exec: " + e.string())
        end
        stmt.close()
      | let e: PrepareError => h.fail("prepare: " + e.string())
      end

      // Read back and verify
      let sel_sql =
        if profile.has_decimal then
          "SELECT d, t, ts, dv FROM _test_bind_dt"
        else
          "SELECT d, t, ts FROM _test_bind_dt"
        end
      match \exhaustive\ conn.query(sel_sql)
      | let cursor: Cursor =>
        match \exhaustive\ cursor.fetch()
        | let row: Row =>
          try
            match \exhaustive\ row.date(ColIndex(1))?
            | let d: SqlDate =>
              h.assert_eq[I16](2025, d.year)
              h.assert_eq[U16](6, d.month)
              h.assert_eq[U16](15, d.day)
            | SqlNull => h.fail("date was null")
            end

            match \exhaustive\ row.time(ColIndex(2))?
            | let t: SqlTime =>
              h.assert_eq[U16](14, t.hour)
              h.assert_eq[U16](30, t.minute)
              h.assert_eq[U16](45, t.second)
            | SqlNull => h.fail("time was null")
            end

            match \exhaustive\ row.timestamp(ColIndex(3))?
            | let ts: SqlTimestamp =>
              h.assert_eq[I16](2025, ts.year)
              h.assert_eq[U16](6, ts.month)
              h.assert_eq[U16](15, ts.day)
              h.assert_eq[U16](14, ts.hour)
              h.assert_eq[U16](30, ts.minute)
              h.assert_eq[U16](45, ts.second)
            | SqlNull => h.fail("timestamp was null")
            end

            if profile.has_decimal then
              match \exhaustive\ row.decimal(ColIndex(4))?
              | let d: SqlDecimal =>
                h.assert_true(
                  d.value.contains("123.45"),
                  "expected 123.45 in: " + d.value)
              | SqlNull => h.fail("decimal was null")
              end
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

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_bind_dt", h)
      conn.close()
    end

primitive _LargeTextByte
  """
  Non-periodic printable-ASCII byte for test position j. A periodic
  generator (e.g. `'a' + j%26`) hides shift/duplicate bugs in the
  SQLGetData fallback, because `result[k] == result[k + p]` whenever p
  is a multiple of the period. Knuth's multiplicative hash gives a
  sequence with no short period over the ranges we test.
  """
  fun apply(j: USize): U8 =>
    // 2654435769 is 2^32/phi, Knuth's well-known multiplicative constant.
    let h = j.u64() * 2654435769
    U8(0x20) + ((h xor (h >> 17)) % 95).u8()

class iso _LargeTextRoundtripTest is UnitTest
  fun name(): String => "integration: large text roundtrip at various sizes"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_largetxt", h)
      _TestSetup.exec(
        conn, "CREATE TABLE _test_largetxt (sz INTEGER, t TEXT)", h)

      // Test sizes: below 4096 floor, at boundary, and well above.
      // SQLGetData fallback handles sizes exceeding the bound buffer.
      let profile = _TestDriver(h)
      let sizes = profile.large_text_sizes

      // Insert rows with strings of each size
      match \exhaustive\
        conn.prepare("INSERT INTO _test_largetxt VALUES (?, ?)")
      | let stmt: Statement =>
        for sz in sizes.values() do
          let text =
            recover val
              let s = String(sz)
              var j: USize = 0
              while j < sz do
                s.push(_LargeTextByte(j))
                j = j + 1
              end
              s
            end
          match stmt.bind(ParamIndex(1), SqlInteger(sz.i32()))
          | let e: BindError => h.fail("bind sz: " + e.string())
          end
          match stmt.bind(ParamIndex(2), SqlText(text))
          | let e: BindError => h.fail("bind text: " + e.string())
          end
          match stmt.execute_update()
          | let e: ExecError => h.fail("insert sz=" + sz.string()
              + ": " + e.string())
          end
        end
        stmt.close()
      | let e: PrepareError => h.fail("prepare: " + e.string())
      end

      // Read back and verify each string matches expected size/content
      match \exhaustive\
        conn.query(
          "SELECT sz, t FROM _test_largetxt ORDER BY sz")
      | let cursor: Cursor =>
        var count: USize = 0
        for result in cursor.values() do
          match \exhaustive\ result
          | let row: Row =>
            count = count + 1
            try
              let sz =
                match row.int(ColIndex(1))?
                | let v: I64 => v.usize()
                else h.fail("null sz"); continue
                end
              let text =
                match row.text(ColIndex(2))?
                | let v: String val => v
                else h.fail("null text for sz=" + sz.string()); continue
                end
              h.assert_eq[USize](
                sz,
                text.size(),
                "size mismatch for sz=" + sz.string())

              // Verify every byte matches the generator output. Full-content
              // comparison catches shift/duplicate bugs anywhere in the value;
              // spot-checking endpoints would miss a middle-of-string tail
              // corruption like the one this pattern is designed to expose.
              try
                var j: USize = 0
                var first_diff: USize = sz // sentinel: means no diff
                while j < sz do
                  if text(j)? != _LargeTextByte(j) then
                    first_diff = j
                    break
                  end
                  j = j + 1
                end
                if first_diff < sz then
                  h.fail("content mismatch for sz=" + sz.string()
                    + " at offset " + first_diff.string()
                    + ": got=" + text(first_diff)?.string()
                    + " want=" + _LargeTextByte(first_diff).string())
                end
              else
                h.fail("byte access error for sz=" + sz.string())
              end
            else
              h.fail("column read error")
            end
          | let e: FetchError =>
            h.fail("fetch error: " + e.string())
          end
        end
        h.assert_eq[USize](sizes.size(), count)
        cursor.close()
      | let e: ExecError => h.fail("query: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_largetxt", h)
      conn.close()
    end

class iso _TextTruncationDetectionTest is UnitTest
  fun name(): String => "integration: text truncation returns ColumnTooLarge"

  fun apply(h: TestHelper) =>
    // Use a small VARCHAR so the buffer is capped at 4096 (the floor),
    // then insert a string that fits in the DB column but would exceed
    // the ODBC read buffer if the driver reports the smaller col_size.
    //
    // With the 4096 floor, VARCHAR(50) gets a 4096-byte buffer, so
    // strings up to 4095 bytes fit. We test with VARCHAR(50) and a
    // 50-byte string to confirm normal operation, then use a prepared
    // statement to insert via TEXT casting to bypass VARCHAR limits
    // and test truncation detection.
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_trunc", h)
      _TestSetup.exec(
        conn, "CREATE TABLE _test_trunc (v VARCHAR(50))", h)

      // Normal case: 50-byte string fits fine in VARCHAR(50) + 4096 buffer
      let small =
        recover val
          let s = String(50)
          var j: USize = 0
          while j < 50 do s.push('x'); j = j + 1 end
          s
        end
      match \exhaustive\
        conn.prepare("INSERT INTO _test_trunc VALUES (?)")
      | let si: Statement =>
        match si.bind(ParamIndex(1), SqlText(small))
        | let e: BindError => h.fail("bind small: " + e.string())
        end
        match si.execute_update()
        | let e: ExecError => h.fail("insert small: " + e.string())
        end
        si.close()
      | let e: PrepareError => h.fail("prepare small: " + e.string())
      end

      match \exhaustive\ conn.query("SELECT v FROM _test_trunc")
      | let cursor: Cursor =>
        match \exhaustive\ cursor.fetch()
        | let row: Row =>
          try
            match row.text(ColIndex(1))?
            | let v: String val =>
              h.assert_eq[USize](
                50, v.size(), "small string should roundtrip")
            else h.fail("null")
            end
          else h.fail("read error") end
        | EndOfRows => h.fail("no rows")
        | let e: FetchError => h.fail("fetch: " + e.string())
        end
        cursor.close()
      | let e: ExecError => h.fail("query: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_trunc", h)

      // Truncation case: use TEXT column with a large string, then read
      // through a subquery that casts to VARCHAR(10) to force a small
      // col_size report. This is driver-dependent; if the driver reports
      // a large col_size anyway, the string will just roundtrip normally.
      let profile = _TestDriver(h)
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_trunc2", h)
      _TestSetup.exec(
        conn, "CREATE TABLE _test_trunc2 (t " + profile.huge_text_col_type
          + ")", h)

      // Insert a 5000-byte string
      let large =
        recover val
          let s = String(5000)
          var j: USize = 0
          while j < 5000 do s.push('y'); j = j + 1 end
          s
        end

      match \exhaustive\
        conn.prepare("INSERT INTO _test_trunc2 VALUES (?)")
      | let stmt: Statement =>
        match stmt.bind(ParamIndex(1), SqlText(large))
        | let e: BindError => h.fail("bind: " + e.string())
        end
        match stmt.execute_update()
        | let e: ExecError => h.fail("insert: " + e.string())
        end
        stmt.close()
      | let e: PrepareError => h.fail("prepare ins: " + e.string())
      end

      // Read it back from the TEXT column — should succeed since
      // the driver reports a large enough col_size for TEXT
      match \exhaustive\ conn.query("SELECT t FROM _test_trunc2")
      | let cursor: Cursor =>
        match \exhaustive\ cursor.fetch()
        | let row: Row =>
          try
            match row.text(ColIndex(1))?
            | let v: String val =>
              h.assert_eq[USize](
                5000, v.size(), "5000-byte TEXT should roundtrip")
            else h.fail("null")
            end
          else h.fail("read error") end
        | EndOfRows => h.fail("no rows")
        | let e: FetchError => h.fail("fetch: " + e.string())
        end
        cursor.close()
      | let e: ExecError => h.fail("query: " + e.string())
      end

      // Now insert a very large string that exceeds the driver's
      // reported col_size for TEXT. The fetch should return
      // ColumnTooLarge instead of silently truncating.
      _TestSetup.exec(conn, "DELETE FROM _test_trunc2", h)

      let huge =
        recover val
          let s = String(100_000)
          var j: USize = 0
          while j < 100_000 do s.push('z'); j = j + 1 end
          s
        end

      match \exhaustive\
        conn.prepare("INSERT INTO _test_trunc2 VALUES (?)")
      | let stmt: Statement =>
        match stmt.bind(ParamIndex(1), SqlText(huge))
        | let e: BindError => h.fail("bind huge: " + e.string())
        end
        match stmt.execute_update()
        | let e: ExecError => h.fail("insert huge: " + e.string())
        end
        stmt.close()
      | let e: PrepareError => h.fail("prepare huge: " + e.string())
      end

      // Read it back — SQLGetData fallback should retrieve the full value
      match \exhaustive\ conn.query("SELECT t FROM _test_trunc2")
      | let cursor: Cursor =>
        match \exhaustive\ cursor.fetch()
        | let row: Row =>
          try
            match row.text(ColIndex(1))?
            | let v: String val =>
              h.assert_eq[USize](
                100_000, v.size(), "100KB string should roundtrip")
            else h.fail("null")
            end
          else h.fail("read error") end
        | EndOfRows => h.fail("no rows")
        | let e: FetchError =>
          h.fail("fetch huge: " + e.string())
        end
        cursor.close()
      | let e: ExecError => h.fail("query huge: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_trunc2", h)
      conn.close()
    end

class iso _MetadataParamTypesTest is UnitTest
  fun name(): String => "integration: Statement.parameter_types"

  fun apply(h: TestHelper) =>
    let profile = _TestDriver(h)
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_meta_params", h)
      _TestSetup.exec(
        conn,
        "CREATE TABLE _test_meta_params"
          + " (id INTEGER NOT NULL, name VARCHAR(32))",
        h)

      match \exhaustive\
        conn.prepare("INSERT INTO _test_meta_params VALUES (?, ?)")
      | let stmt: Statement =>
        match \exhaustive\ stmt.parameter_types()
        | let tags: Array[SqlTypeTag] val =>
          h.assert_eq[USize](2, tags.size(), "expected 2 param tags")
          if profile.describe_param_accurate then
            try
              match tags(0)?
              | SqlTagInteger => None
              else h.fail("param 1 should be Integer, was "
                + tags(0)?.string())
              end
              match tags(1)?
              | SqlTagText => None
              else h.fail("param 2 should be Text, was "
                + tags(1)?.string())
              end
            else
              h.fail("param tag read error")
            end
          else
            h.log(
              profile.name
                + " does not accurately describe params; "
                + "tag check skipped")
          end
        | let e: MetadataError =>
          h.fail("parameter_types: " + e.string())
        end
        stmt.close()
      | let e: PrepareError => h.fail("prepare: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_meta_params", h)
      conn.close()
    end

class iso _MetadataColumnTypesTest is UnitTest
  fun name(): String => "integration: Statement.column_types"

  fun apply(h: TestHelper) =>
    let profile = _TestDriver(h)
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_meta_cols", h)
      _TestSetup.exec(
        conn,
        "CREATE TABLE _test_meta_cols"
          + " (id INTEGER NOT NULL, name VARCHAR(32), created TIMESTAMP)",
        h)

      match \exhaustive\
        conn.prepare(
          "SELECT id, name, created FROM _test_meta_cols WHERE id > ?")
      | let stmt: Statement =>
        match \exhaustive\ stmt.column_types()
        | let cols: Array[ColumnMeta] val =>
          h.assert_eq[USize](3, cols.size(), "expected 3 columns")
          try
            let c0 = cols(0)?
            h.assert_eq[String val]("id", c0.name)
            match c0.type_tag
            | SqlTagInteger => None
            else h.fail("col id should be Integer")
            end
            if profile.reports_not_null then
              match c0.nullable
              | NoNulls => None
              else h.fail("col id should be NOT NULL, was "
                + c0.nullable.string())
              end
            end

            let c1 = cols(1)?
            h.assert_eq[String val]("name", c1.name)
            match c1.type_tag
            | SqlTagText => None
            else h.fail("col name should be Text")
            end
            match c1.nullable
            | Nullable => None
            | NullableUnknown => None
            else h.fail("col name should be Nullable/Unknown, was "
              + c1.nullable.string())
            end

            let c2 = cols(2)?
            h.assert_eq[String val]("created", c2.name)
            match c2.type_tag
            | SqlTagTimestamp => None
            else h.fail("col created should be Timestamp")
            end
          else
            h.fail("column meta read error")
          end
        | let e: MetadataError => h.fail("column_types: " + e.string())
        end
        stmt.close()
      | let e: PrepareError => h.fail("prepare: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_meta_cols", h)
      conn.close()
    end

class iso _MetadataEmptyTest is UnitTest
  fun name(): String => "integration: metadata for 0-param / 0-column statements"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_meta_empty", h)
      _TestSetup.exec(
        conn, "CREATE TABLE _test_meta_empty (id INTEGER)", h)

      // 0-param SELECT: parameter_types empty, column_types non-empty.
      match \exhaustive\ conn.prepare("SELECT id FROM _test_meta_empty")
      | let stmt: Statement =>
        match \exhaustive\ stmt.parameter_types()
        | let tags: Array[SqlTypeTag] val =>
          h.assert_eq[USize](0, tags.size(), "0 params expected")
        | let e: MetadataError => h.fail("parameter_types: " + e.string())
        end

        match \exhaustive\ stmt.column_types()
        | let cols: Array[ColumnMeta] val =>
          h.assert_eq[USize](1, cols.size(), "1 column expected")
        | let e: MetadataError => h.fail("column_types: " + e.string())
        end
        stmt.close()
      | let e: PrepareError => h.fail("prepare select: " + e.string())
      end

      // 0-column INSERT (DML): column_types returns empty, params non-empty.
      match \exhaustive\
        conn.prepare("INSERT INTO _test_meta_empty VALUES (?)")
      | let stmt: Statement =>
        match \exhaustive\ stmt.column_types()
        | let cols: Array[ColumnMeta] val =>
          h.assert_eq[USize](0, cols.size(), "0 result cols expected")
        | let e: MetadataError => h.fail("column_types: " + e.string())
        end

        match \exhaustive\ stmt.parameter_types()
        | let tags: Array[SqlTypeTag] val =>
          h.assert_eq[USize](1, tags.size(), "1 param expected")
        | let e: MetadataError =>
          h.fail("parameter_types: " + e.string())
        end
        stmt.close()
      | let e: PrepareError => h.fail("prepare insert: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_meta_empty", h)
      conn.close()
    end

class iso _MetadataClosedTest is UnitTest
  fun name(): String => "integration: metadata after close returns closed errors"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?

      match \exhaustive\ conn.prepare("SELECT 1")
      | let stmt: Statement =>
        stmt.close()

        match stmt.parameter_types()
        | let _: Array[SqlTypeTag] val =>
          h.fail("parameter_types on closed statement should error")
        | let e: MetadataError =>
          match e.kind()
          | MetadataStatementClosed => None
          else h.fail(
            "expected MetadataStatementClosed, got: " + e.string())
          end
        end

        match stmt.column_types()
        | let _: Array[ColumnMeta] val =>
          h.fail("column_types on closed statement should error")
        | let e: MetadataError =>
          match e.kind()
          | MetadataStatementClosed => None
          else h.fail(
            "expected MetadataStatementClosed, got: " + e.string())
          end
        end
      | let e: PrepareError => h.fail("prepare: " + e.string())
      end

      // MetadataConnectionClosed: statement open, connection closed.
      match \exhaustive\ conn.prepare("SELECT 1")
      | let stmt: Statement =>
        conn.close()

        match stmt.parameter_types()
        | let _: Array[SqlTypeTag] val =>
          h.fail("parameter_types after conn close should error")
        | let e: MetadataError =>
          match e.kind()
          | MetadataConnectionClosed => None
          else h.fail(
            "expected MetadataConnectionClosed, got: " + e.string())
          end
        end
      | let e: PrepareError => h.fail("prepare2: " + e.string())
      end
    end

class iso _DbSessionTest is UnitTest
  fun name(): String => "integration: DbSession actor with promises"

  fun apply(h: TestHelper) =>
    h.long_test(5_000_000_000) // 5 second timeout

    let dsn = _TestDsn.dsn(h)
    let db = DbSession(dsn)

    // Chain: drop → create → insert → query → verify → cleanup
    let p_drop = Promise[(RowCount | ExecError)]
    db.exec("DROP TABLE IF EXISTS _test_session", p_drop)

    p_drop.next[None](
      {(result: (RowCount | ExecError))(db, h) =>
        let p_create = Promise[(RowCount | ExecError)]
        db.exec(
          "CREATE TABLE _test_session (id INTEGER, name VARCHAR(32))",
          p_create)

        p_create.next[None](
          {(result: (RowCount | ExecError))(db, h) =>
            match result
            | let _: ExecError =>
              h.fail("create failed")
              h.complete(false)
              return
            end

            let p_ins = Promise[(RowCount | ExecError)]
            db.exec(
              "INSERT INTO _test_session VALUES (1, 'promise')", p_ins)

            p_ins.next[None](
              {(result: (RowCount | ExecError))(db, h) =>
                let p_query = Promise[(Array[Row val] val | ExecError)]
                db.query("SELECT id, name FROM _test_session", p_query)

                p_query.next[None](
                  {(result: (Array[Row val] val | ExecError))(db, h) =>
                    match \exhaustive\ result
                    | let rows: Array[Row val] val =>
                      h.assert_eq[USize](1, rows.size())
                      try
                        match rows(0)?.int(ColIndex(1))?
                        | let v: I64 => h.assert_eq[I64](1, v)
                        else h.fail("null id")
                        end
                        match rows(0)?.text(ColIndex(2))?
                        | let v: String val =>
                          h.assert_eq[String val]("promise", v)
                        else h.fail("null name")
                        end
                      else
                        h.fail("row read error")
                      end
                    | let e: ExecError =>
                      h.fail("query: " + e.string())
                    end

                    // Cleanup
                    let p_cleanup = Promise[(RowCount | ExecError)]
                    db.exec("DROP TABLE IF EXISTS _test_session", p_cleanup)
                    p_cleanup.next[None](
                      {(result: (RowCount | ExecError))(db, h) =>
                        db.close()
                        h.complete(true)
                      })
                  })
              })
          })
      })
