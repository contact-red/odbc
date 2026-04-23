use "pony_test"
use "pony_check"
use ".."

class val _LargeTextInput
  let size: USize
  let offset: USize

  new val create(size': USize, offset': USize) =>
    size = size'
    offset = offset'

primitive _LargeTextGen
  """
  Generator for (size, offset) pairs that drive the property-style
  large-text roundtrip test. Sizes are biased toward small and
  bound-buffer-boundary ranges so iterations stay fast while still
  exercising the bound-buffer / SQLGetData boundary at 4096 bytes.
  Offsets randomize the starting position in the _LargeTextByte
  sequence so each sample roundtrips a different window of the
  non-periodic byte stream — this catches shift/duplicate bugs that
  a fixed-offset-zero test would miss.
  """
  fun apply(): Generator[_LargeTextInput] =>
    Generator[_LargeTextInput](
      object is GenObj[_LargeTextInput]
        fun generate(rnd: Randomness): _LargeTextInput^ =>
          let which = rnd.usize(0, 200)
          let size =
            if which < 30 then
              rnd.usize(0, 100)
            elseif which < 55 then
              rnd.usize(100, 4095)
            elseif which < 80 then
              rnd.usize(4090, 8200)
            elseif which < 95 then
              rnd.usize(8200, 32000)
            else
              rnd.usize(32000, 1000000)
            end
          let offset = rnd.usize(0, 10000)
          _LargeTextInput(size, offset)
      end)

class iso _LargeTextGenRoundtripTest is UnitTest
  """
  Generative counterpart to _LargeTextRoundtripTest. Uses the
  pony_check Generator abstraction to draw 100 (size, offset)
  samples with a deterministic seed, inserts each through one
  prepared statement, then reads every row back and verifies byte
  content against the generator. Pairing this with the example-based
  test gives both fixed-boundary coverage and randomized coverage
  of non-boundary byte positions.
  """
  fun name(): String =>
    "integration: large text roundtrip (pony_check generator)"

  fun apply(h: TestHelper) =>
    try
      let conn = _TestSetup.connect(h)?
      let profile = _TestDriver(h)
      _TestSetup.exec(
        conn, "DROP TABLE IF EXISTS _test_largetxt_prop", h)
      _TestSetup.exec(
        conn,
        "CREATE TABLE _test_largetxt_prop"
          + " (sz INTEGER, ofs INTEGER, t "
          + profile.huge_text_col_type + ")",
        h)

      let rnd = Randomness(42)
      let gen = _LargeTextGen()
      let samples: USize = 100

      match \exhaustive\
        conn.prepare(
          "INSERT INTO _test_largetxt_prop VALUES (?, ?, ?)")
      | let stmt: Statement =>
        var i: USize = 0
        while i < samples do
          let input =
            try gen.generate_value(rnd)?
            else
              h.fail("generator failed at i=" + i.string())
              i = i + 1
              continue
            end
          let content =
            recover val
              let s = String(input.size)
              var j: USize = 0
              while j < input.size do
                s.push(_LargeTextByte(input.offset + j))
                j = j + 1
              end
              s
            end

          match stmt.bind(ParamIndex(1), SqlInteger(input.size.i32()))
          | let e: BindError =>
            h.fail("bind sz at i=" + i.string() + ": " + e.string())
          end
          match stmt.bind(ParamIndex(2), SqlInteger(input.offset.i32()))
          | let e: BindError =>
            h.fail("bind ofs at i=" + i.string() + ": " + e.string())
          end
          match stmt.bind(ParamIndex(3), SqlText(content))
          | let e: BindError =>
            h.fail("bind t at i=" + i.string() + ": " + e.string())
          end
          match stmt.execute_update()
          | let e: ExecError =>
            h.fail("insert at i=" + i.string()
              + " size=" + input.size.string()
              + " ofs=" + input.offset.string() + ": " + e.string())
          end
          i = i + 1
        end
        stmt.close()
      | let e: PrepareError => h.fail("prepare: " + e.string())
      end

      match \exhaustive\
        conn.query("SELECT sz, ofs, t FROM _test_largetxt_prop")
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
              let ofs =
                match row.int(ColIndex(2))?
                | let v: I64 => v.usize()
                else h.fail("null ofs"); continue
                end
              let text =
                match row.text(ColIndex(3))?
                | let v: String val => v
                else
                  h.fail("null text for sz=" + sz.string()
                    + " ofs=" + ofs.string())
                  continue
                end

              h.assert_eq[USize](
                sz, text.size(),
                "size mismatch for sz=" + sz.string()
                  + " ofs=" + ofs.string())

              try
                var j: USize = 0
                var first_diff: USize = sz
                while j < sz do
                  if text(j)? != _LargeTextByte(ofs + j) then
                    first_diff = j
                    break
                  end
                  j = j + 1
                end
                if first_diff < sz then
                  h.fail("content mismatch for sz=" + sz.string()
                    + " ofs=" + ofs.string()
                    + " at offset " + first_diff.string()
                    + ": got=" + text(first_diff)?.string()
                    + " want="
                    + _LargeTextByte(ofs + first_diff).string())
                end
              else
                h.fail("byte access error for sz=" + sz.string()
                  + " ofs=" + ofs.string())
              end
            else
              h.fail("column read error")
            end
          | let e: FetchError => h.fail("fetch: " + e.string())
          end
        end
        h.assert_eq[USize](samples, count)
        cursor.close()
      | let e: ExecError => h.fail("query: " + e.string())
      end

      _TestSetup.exec(
        conn, "DROP TABLE IF EXISTS _test_largetxt_prop", h)
      conn.close()
    end
