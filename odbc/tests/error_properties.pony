use "pony_test"
use "pony_check"
use ".."

class val _SqlstateInput
  let sqlstate: String val
  let expected_str: String val

  new val create(sqlstate': String val, expected_str': String val) =>
    sqlstate = sqlstate'
    expected_str = expected_str'

class iso _SqlstateClassifierProperty is Property1[_SqlstateInput]
  fun name(): String => "SQLSTATE classifier maps classes correctly"

  fun gen(): Generator[_SqlstateInput] =>
    Generator[_SqlstateInput](
      object is GenObj[_SqlstateInput]
        fun generate(rnd: Randomness): _SqlstateInput^ =>
          let which = rnd.usize(0, 3)
          let suffix =
            recover val
            String(3)
              .> push(rnd.u8(0x30, 0x39))
              .> push(rnd.u8(0x30, 0x39))
              .> push(rnd.u8(0x30, 0x39))
          end
          match which
          | 0 => _SqlstateInput("08" + suffix, "connection lost")
          | 1 => _SqlstateInput("23" + suffix, "constraint violation")
          | 2 => _SqlstateInput("42" + suffix, "syntax error")
          else
            let prefix =
              recover val
              let s = String(2)
              // Avoid 08, 23, 42
              let p = rnd.usize(0, 4)
              match p
              | 0 => s.append("01")
              | 1 => s.append("07")
              | 2 => s.append("22")
              | 3 => s.append("25")
              else s.append("HY")
              end
              s
            end
            _SqlstateInput(prefix + suffix, "query error")
          end
      end)

  fun property(input: _SqlstateInput, ph: PropertyHelper) =>
    let diag: DiagChain =
      recover val
      Array[DiagRecord] .> push(DiagRecord(input.sqlstate, 0, "test"))
    end
    let result = ExecErrorClassifier.classify(diag)
    ph.assert_eq[String val](input.expected_str, result.string())

class val _DescribeParamStateInput
  let sqlstate: String val
  let expects_unsupported: Bool

  new val create(sqlstate': String val, expects_unsupported': Bool) =>
    sqlstate = sqlstate'
    expects_unsupported = expects_unsupported'

class iso _DescribeParamClassifierProperty
  is Property1[_DescribeParamStateInput]
  fun name(): String =>
    "DescribeParam classifier maps IM001/HYC00 to unsupported"

  fun gen(): Generator[_DescribeParamStateInput] =>
    Generator[_DescribeParamStateInput](
      object is GenObj[_DescribeParamStateInput]
        fun generate(rnd: Randomness): _DescribeParamStateInput^ =>
          let which = rnd.usize(0, 4)
          match which
          | 0 => _DescribeParamStateInput("IM001", true)
          | 1 => _DescribeParamStateInput("HYC00", true)
          | 2 => _DescribeParamStateInput("HY000", false)
          | 3 => _DescribeParamStateInput("42S02", false)
          else
            // Random non-matching state.
            let s =
              recover val
                let buf = String(5)
                var i: USize = 0
                while i < 5 do
                  buf.push(rnd.u8(0x30, 0x39))
                  i = i + 1
                end
                buf
              end
            _DescribeParamStateInput(s,
              (s == "IM001") or (s == "HYC00"))
          end
      end)

  fun property(
    input: _DescribeParamStateInput, ph: PropertyHelper)
  =>
    let diag: DiagChain =
      recover val
      Array[DiagRecord] .> push(
        DiagRecord(input.sqlstate, 0, "test"))
    end
    let kind = DescribeParamErrorClassifier.classify(diag)
    if input.expects_unsupported then
      match kind
      | DriverDoesNotSupportDescribeParam => None
      else
        ph.fail(
          "expected DriverDoesNotSupportDescribeParam for "
            + input.sqlstate + ", got " + kind.string())
      end
    else
      match kind
      | DriverMetadataError => None
      else
        ph.fail(
          "expected DriverMetadataError for "
            + input.sqlstate + ", got " + kind.string())
      end
    end

class val _DiagLeakInput
  let secret_text: String val
  let sqlstate: String val

  new val create(secret_text': String val, sqlstate': String val) =>
    secret_text = secret_text'
    sqlstate = sqlstate'

class iso _ErrorRedactionProperty is Property1[_DiagLeakInput]
  fun name(): String => "error.string() never contains raw diagnostic message"

  fun gen(): Generator[_DiagLeakInput] =>
    Generator[_DiagLeakInput](
      object is GenObj[_DiagLeakInput]
        fun generate(rnd: Randomness): _DiagLeakInput^ =>
          let len = rnd.usize(5, 30)
          let secret =
            recover val
            let s = String(len + 7)
            s.append("SECRET_")
            var i: USize = 0
            while i < len do
              s.push(rnd.u8(0x41, 0x5A)) // uppercase ASCII
              i = i + 1
            end
            s
          end
          let state =
            recover val
            let s = String(5)
            var i: USize = 0
            while i < 5 do s.push(rnd.u8(0x30, 0x39)); i = i + 1 end
            s
          end
          _DiagLeakInput(secret, state)
      end)

  fun property(input: _DiagLeakInput, ph: PropertyHelper) =>
    let diag: DiagChain =
      recover val
      Array[DiagRecord] .> push(
        DiagRecord(
          input.sqlstate, 42, input.secret_text))
    end

    // ConnectError.string() must not contain the secret
    let ce = ConnectError(DriverConnectFailed, diag)
    let ce_str: String val = ce.string()
    ph.assert_false(
      ce_str.contains(input.secret_text),
      "ConnectError leaked: " + ce_str)

    // ExecError.string() must not contain secret or SQL
    let ee =
      ExecError(
        QueryError, diag, "SELECT secret FROM passwords")
    let ee_str: String val = ee.string()
    ph.assert_false(
      ee_str.contains(input.secret_text),
      "ExecError leaked diag: " + ee_str)
    ph.assert_false(
      ee_str.contains("passwords"),
      "ExecError leaked SQL: " + ee_str)

    // PrepareError.string() must not contain secret or SQL
    let pe =
      PrepareError(
        DriverPrepareError, diag, "CREATE USER foo PASSWORD 'bar'")
    let pe_str: String val = pe.string()
    ph.assert_false(
      pe_str.contains(input.secret_text),
      "PrepareError leaked diag: " + pe_str)
    ph.assert_false(
      pe_str.contains("PASSWORD"),
      "PrepareError leaked SQL: " + pe_str)

    // But unsafe_diag() SHOULD contain it
    try
      let first_msg = ce.unsafe_diag()(0)?.message()
      ph.assert_eq[String val](
        first_msg, input.secret_text)
    else
      ph.fail("unsafe_diag() didn't contain the secret")
    end

    // And unsafe_sql() SHOULD contain the SQL
    match ee.unsafe_sql()
    | let s: String val =>
      ph.assert_true(s.contains("passwords"))
    else
      ph.fail("unsafe_sql() returned None")
    end

class val _SqlValueInput
  let value: SqlValue

  new val create(value': SqlValue) =>
    value = value'

class iso _SqlValueRoundtripProperty is Property1[_SqlValueInput]
  fun name(): String => "SqlValue -> Row -> typed accessor preserves value"

  fun gen(): Generator[_SqlValueInput] =>
    Generator[_SqlValueInput](
      object is GenObj[_SqlValueInput]
        fun generate(rnd: Randomness): _SqlValueInput^ =>
          _SqlValueInput(_GenHelper.random_sql_value(rnd))
      end)

  fun property(input: _SqlValueInput, ph: PropertyHelper) =>
    let cols =
      recover iso
      Array[SqlValue](1) .> push(input.value)
    end
    let row = Row.create(consume cols)
    let ci = ColIndex(1)

    match \exhaustive\ input.value
    | SqlNull =>
      try ph.assert_true(row.is_null(ci)?)
      else ph.fail("is_null raised error") end
    | let v: SqlBool =>
      try
        match row.bool(ci)?
        | let r: Bool => ph.assert_eq[Bool](v.value, r)
        else ph.fail("bool returned SqlNull") end
      else ph.fail("bool raised error") end
    | let v: SqlTinyInt =>
      try
        match row.int(ci)?
        | let r: I64 => ph.assert_eq[I64](v.value.i64(), r)
        else ph.fail("int returned SqlNull") end
      else ph.fail("int raised error") end
    | let v: SqlSmallInt =>
      try
        match row.int(ci)?
        | let r: I64 => ph.assert_eq[I64](v.value.i64(), r)
        else ph.fail("int returned SqlNull") end
      else ph.fail("int raised error") end
    | let v: SqlInteger =>
      try
        match row.int(ci)?
        | let r: I64 => ph.assert_eq[I64](v.value.i64(), r)
        else ph.fail("int returned SqlNull") end
      else ph.fail("int raised error") end
    | let v: SqlBigInt =>
      try
        match row.int(ci)?
        | let r: I64 => ph.assert_eq[I64](v.value, r)
        else ph.fail("int returned SqlNull") end
      else ph.fail("int raised error") end
    | let v: SqlFloat =>
      try
        match row.float(ci)?
        | let r: F64 => ph.assert_eq[F64](v.value, r)
        else ph.fail("float returned SqlNull") end
      else ph.fail("float raised error") end
    | let v: SqlText =>
      try
        match row.text(ci)?
        | let r: String val => ph.assert_eq[String val](v.value, r)
        else ph.fail("text returned SqlNull") end
      else ph.fail("text raised error") end
    | let v: SqlDate =>
      try
        match row.date(ci)?
        | let r: SqlDate =>
          ph.assert_eq[I16](v.year, r.year)
          ph.assert_eq[U16](v.month, r.month)
          ph.assert_eq[U16](v.day, r.day)
        else ph.fail("date returned SqlNull") end
      else ph.fail("date raised error") end
    | let v: SqlTime =>
      try
        match row.time(ci)?
        | let r: SqlTime =>
          ph.assert_eq[U16](v.hour, r.hour)
          ph.assert_eq[U16](v.minute, r.minute)
          ph.assert_eq[U16](v.second, r.second)
        else ph.fail("time returned SqlNull") end
      else ph.fail("time raised error") end
    | let v: SqlTimestamp =>
      try
        match row.timestamp(ci)?
        | let r: SqlTimestamp =>
          ph.assert_eq[I16](v.year, r.year)
          ph.assert_eq[U16](v.month, r.month)
          ph.assert_eq[U16](v.day, r.day)
          ph.assert_eq[U16](v.hour, r.hour)
          ph.assert_eq[U16](v.minute, r.minute)
          ph.assert_eq[U16](v.second, r.second)
          ph.assert_eq[U32](v.fraction, r.fraction)
        else ph.fail("timestamp returned SqlNull") end
      else ph.fail("timestamp raised error") end
    | let v: SqlDecimal =>
      try
        match row.decimal(ci)?
        | let r: SqlDecimal =>
          ph.assert_eq[String val](v.value, r.value)
        else ph.fail("decimal returned SqlNull") end
      else ph.fail("decimal raised error") end
    end
