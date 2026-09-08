use "pony_test"
use "pony_check"
use ".."

class iso _BinaryTypesTest is UnitTest
  fun name(): String => "integration: binary roundtrip via INSERT literal"

  fun apply(h: TestHelper) =>
    let profile = _TestDriver(h)
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_bin", h)
      _TestSetup.exec(
        conn,
        "CREATE TABLE _test_bin (b " + profile.binary_col_type + ")",
        h)

      // Insert a known byte sequence as a hex literal.
      // x'DEADBEEF' is standard SQL hex literal syntax.
      _TestSetup.exec(
        conn, "INSERT INTO _test_bin VALUES (x'DEADBEEF')", h)

      match \exhaustive\ conn.query("SELECT b FROM _test_bin")
      | let cursor: Cursor =>
        match \exhaustive\ cursor.fetch()
        | let row: Row =>
          try
            match row.binary(ColIndex(1))?
            | let v: Array[U8] val =>
              h.assert_eq[USize](4, v.size(), "expected 4 bytes")
              h.assert_eq[U8](0xDE, v(0)?)
              h.assert_eq[U8](0xAD, v(1)?)
              h.assert_eq[U8](0xBE, v(2)?)
              h.assert_eq[U8](0xEF, v(3)?)
            | SqlNull => h.fail("binary was null")
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

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_bin", h)
      conn.close()
    end

class iso _BindBinaryTest is UnitTest
  fun name(): String => "integration: bind binary params"

  fun apply(h: TestHelper) =>
    let profile = _TestDriver(h)
    try
      let conn = _TestSetup.connect(h)?
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_bind_bin", h)
      _TestSetup.exec(
        conn,
        "CREATE TABLE _test_bind_bin (b " + profile.binary_col_type + ")",
        h)

      let bytes: Array[U8] val =
        recover val
          let a = Array[U8](8)
          a.>push(0x00).>push(0x01).>push(0x7F)
            .>push(0x80).>push(0xFE).>push(0xFF)
            .>push(0x00).>push(0x42)
          a
        end

      match \exhaustive\ conn.prepare("INSERT INTO _test_bind_bin VALUES (?)")
      | let stmt: Statement =>
        match stmt.bind(ParamIndex(1), SqlBinary(bytes))
        | let e: BindError => h.fail("bind: " + e.string())
        end
        match \exhaustive\ stmt.execute_update()
        | let n: USize => h.assert_eq[USize](1, n)
        | NoRowCount => None
        | let e: ExecError => h.fail("exec: " + e.string())
        end
        stmt.close()
      | let e: PrepareError => h.fail("prepare: " + e.string())
      end

      // Also bind an empty binary to confirm zero-length roundtrip
      let empty: Array[U8] val = recover val Array[U8] end
      match \exhaustive\ conn.prepare("INSERT INTO _test_bind_bin VALUES (?)")
      | let stmt: Statement =>
        match stmt.bind(ParamIndex(1), SqlBinary(empty))
        | let e: BindError => h.fail("bind empty: " + e.string())
        end
        match \exhaustive\ stmt.execute_update()
        | let n: USize => h.assert_eq[USize](1, n)
        | NoRowCount => None
        | let e: ExecError => h.fail("exec empty: " + e.string())
        end
        stmt.close()
      | let e: PrepareError => h.fail("prepare empty: " + e.string())
      end

      match \exhaustive\
        conn.query("SELECT b FROM _test_bind_bin ORDER BY length(b)")
      | let cursor: Cursor =>
        // First row: empty binary
        match \exhaustive\ cursor.fetch()
        | let row: Row =>
          try
            match row.binary(ColIndex(1))?
            | let v: Array[U8] val =>
              h.assert_eq[USize](0, v.size(), "empty should be 0 bytes")
            | SqlNull => h.fail("empty binary was null")
            end
          else h.fail("column read error (empty)") end
        | EndOfRows => h.fail("no rows")
        | let e: FetchError => h.fail("fetch empty: " + e.string())
        end

        // Second row: 8-byte payload with embedded nulls
        match \exhaustive\ cursor.fetch()
        | let row: Row =>
          try
            match row.binary(ColIndex(1))?
            | let v: Array[U8] val =>
              h.assert_eq[USize](8, v.size(), "expected 8 bytes")
              h.assert_eq[U8](0x00, v(0)?)
              h.assert_eq[U8](0x01, v(1)?)
              h.assert_eq[U8](0x7F, v(2)?)
              h.assert_eq[U8](0x80, v(3)?)
              h.assert_eq[U8](0xFE, v(4)?)
              h.assert_eq[U8](0xFF, v(5)?)
              h.assert_eq[U8](0x00, v(6)?)
              h.assert_eq[U8](0x42, v(7)?)
            | SqlNull => h.fail("binary was null")
            end
          else h.fail("column read error") end
        | EndOfRows => h.fail("expected second row")
        | let e: FetchError => h.fail("fetch: " + e.string())
        end
        cursor.close()
      | let e: ExecError => h.fail("query: " + e.string())
      end

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_bind_bin", h)
      conn.close()
    end

primitive _LargeBinaryByte
  """
  Non-periodic byte for test position j. Uses the same Knuth
  multiplicative hash as _LargeTextByte but over the full 0x00-0xFF
  range (binary data has no printable-ASCII constraint).
  """
  fun apply(j: USize): U8 =>
    let hash = j.u64() * 2654435769
    ((hash xor (hash >> 17)) % 256).u8()

class iso _LargeBinaryRoundtripTest is UnitTest
  fun name(): String =>
    "integration: large binary roundtrip at various sizes"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?
      let profile = _TestDriver(h)
      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_largebin", h)
      _TestSetup.exec(
        conn,
        "CREATE TABLE _test_largebin (sz INTEGER, b "
          + profile.large_binary_col_type + ")",
        h)

      let sizes = profile.large_binary_sizes

      match \exhaustive\
        conn.prepare("INSERT INTO _test_largebin VALUES (?, ?)")
      | let stmt: Statement =>
        for sz in sizes.values() do
          let blob =
            recover val
              let a = Array[U8](sz)
              var j: USize = 0
              while j < sz do
                a.push(_LargeBinaryByte(j))
                j = j + 1
              end
              a
            end
          match stmt.bind(ParamIndex(1), SqlInteger(sz.i32()))
          | let e: BindError => h.fail("bind sz: " + e.string())
          end
          match stmt.bind(ParamIndex(2), SqlBinary(blob))
          | let e: BindError => h.fail("bind bin: " + e.string())
          end
          match stmt.execute_update()
          | let e: ExecError => h.fail("insert sz=" + sz.string()
              + ": " + e.string())
          end
        end
        stmt.close()
      | let e: PrepareError => h.fail("prepare: " + e.string())
      end

      match \exhaustive\
        conn.query("SELECT sz, b FROM _test_largebin ORDER BY sz")
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
              let blob =
                match row.binary(ColIndex(2))?
                | let v: Array[U8] val => v
                else
                  h.fail("null binary for sz=" + sz.string())
                  continue
                end
              h.assert_eq[USize](
                sz,
                blob.size(),
                "size mismatch for sz=" + sz.string())

              try
                var j: USize = 0
                var first_diff: USize = sz
                while j < sz do
                  if blob(j)? != _LargeBinaryByte(j) then
                    first_diff = j
                    break
                  end
                  j = j + 1
                end
                if first_diff < sz then
                  h.fail("content mismatch for sz=" + sz.string()
                    + " at offset " + first_diff.string()
                    + ": got=" + blob(first_diff)?.string()
                    + " want=" + _LargeBinaryByte(first_diff).string())
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

      _TestSetup.exec(conn, "DROP TABLE IF EXISTS _test_largebin", h)
      conn.close()
    end
