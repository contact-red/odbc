use "pony_test"
use "pony_check"
use ".."

class val _RowTestInput
  let row: Row
  let col: ColIndex
  let expected: SqlValue

  new val create(row': Row, col': ColIndex, expected': SqlValue) =>
    row = row'
    col = col'
    expected = expected'

primitive _GenHelper
  fun random_sql_value(rnd: Randomness): SqlValue =>
    let which = rnd.usize(0, 11)
    match which
    | 0 => SqlTinyInt(rnd.i8())
    | 1 => SqlSmallInt(rnd.i16())
    | 2 => SqlInteger(rnd.i32())
    | 3 => SqlBigInt(rnd.i64())
    | 4 => SqlFloat(rnd.f64())
    | 5 =>
      let len = rnd.usize(0, 20)
      let s =
        recover val
        let buf = String(len)
        var i: USize = 0
        while i < len do
          buf.push(rnd.u8(0x20, 0x7E))
          i = i + 1
        end
        buf
      end
      SqlText(s)
    | 6 => SqlBool(rnd.bool())
    | 7 =>
      SqlDate(rnd.i16(-9999, 9999), rnd.u16(1, 12), rnd.u16(1, 28))
    | 8 =>
      SqlTime(rnd.u16(0, 23), rnd.u16(0, 59), rnd.u16(0, 59))
    | 9 =>
      SqlTimestamp(
        rnd.i16(-9999, 9999),
        rnd.u16(1, 12),
        rnd.u16(1, 28),
        rnd.u16(0, 23),
        rnd.u16(0, 59),
        rnd.u16(0, 59),
        rnd.u32(0, 999_999_999))
    | 10 =>
      let len = rnd.usize(1, 15)
      let s =
        recover val
        let buf = String(len + 3)
        var i: USize = 0
        while i < len do
          buf.push(rnd.u8(0x30, 0x39))
          i = i + 1
        end
        buf.push('.')
        buf.push(rnd.u8(0x30, 0x39))
        buf.push(rnd.u8(0x30, 0x39))
        buf
      end
      SqlDecimal(s)
    else SqlNull
    end

  fun row_test_input(rnd: Randomness): _RowTestInput =>
    let num_cols = rnd.usize(3, 5)
    let cols = recover iso Array[SqlValue](num_cols) end
    var i: USize = 0
    while i < num_cols do
      cols.push(random_sql_value(rnd))
      i = i + 1
    end
    let test_col = rnd.usize(0, num_cols - 1)
    let expected: SqlValue = try cols(test_col)? else SqlNull end
    let row = Row.create(consume cols)
    _RowTestInput(row, ColIndex((test_col + 1).u16()), expected)

class iso _RowIntAccessorProperty is Property1[_RowTestInput]
  fun name(): String =>
    "row.int() returns value for integer types, error for others"

  fun gen(): Generator[_RowTestInput] =>
    Generator[_RowTestInput](
      object is GenObj[_RowTestInput]
        fun generate(rnd: Randomness): _RowTestInput^ =>
          _GenHelper.row_test_input(rnd)
      end)

  fun property(input: _RowTestInput, ph: PropertyHelper) =>
    try
      let result = input.row.int(input.col)?
      match input.expected
      | let v: SqlTinyInt =>
        match result
        | let r: I64 => ph.assert_eq[I64](v.value.i64(), r)
        else ph.fail("expected I64, got SqlNull")
        end
      | let v: SqlSmallInt =>
        match result
        | let r: I64 => ph.assert_eq[I64](v.value.i64(), r)
        else ph.fail("expected I64, got SqlNull")
        end
      | let v: SqlInteger =>
        match result
        | let r: I64 => ph.assert_eq[I64](v.value.i64(), r)
        else ph.fail("expected I64, got SqlNull")
        end
      | let v: SqlBigInt =>
        match result
        | let r: I64 => ph.assert_eq[I64](v.value, r)
        else ph.fail("expected I64, got SqlNull")
        end
      | SqlNull =>
        match result
        | SqlNull => None
        else ph.fail("expected SqlNull")
        end
      else
        ph.fail("int() should have raised error for non-int column")
      end
    else
      match input.expected
      | let _: SqlTinyInt => ph.fail("int() raised error on SqlTinyInt")
      | let _: SqlSmallInt => ph.fail("int() raised error on SqlSmallInt")
      | let _: SqlInteger => ph.fail("int() raised error on SqlInteger")
      | let _: SqlBigInt => ph.fail("int() raised error on SqlBigInt")
      | SqlNull => ph.fail("int() raised error on SqlNull column")
      else None
      end
    end

class iso _RowFloatAccessorProperty is Property1[_RowTestInput]
  fun name(): String =>
    "row.float() returns value for SqlFloat, error for others"

  fun gen(): Generator[_RowTestInput] =>
    Generator[_RowTestInput](
      object is GenObj[_RowTestInput]
        fun generate(rnd: Randomness): _RowTestInput^ =>
          _GenHelper.row_test_input(rnd)
      end)

  fun property(input: _RowTestInput, ph: PropertyHelper) =>
    try
      let result = input.row.float(input.col)?
      match input.expected
      | let v: SqlFloat =>
        match result
        | let r: F64 => ph.assert_eq[F64](v.value, r)
        else ph.fail("expected F64, got SqlNull")
        end
      | SqlNull =>
        match result
        | SqlNull => None
        else ph.fail("expected SqlNull")
        end
      else ph.fail("float() should have raised error")
      end
    else
      match input.expected
      | let _: SqlFloat => ph.fail("float() raised error on SqlFloat")
      | SqlNull => ph.fail("float() raised error on SqlNull")
      else None
      end
    end

class iso _RowTextAccessorProperty is Property1[_RowTestInput]
  fun name(): String => "row.text() returns value for SqlText, error for others"

  fun gen(): Generator[_RowTestInput] =>
    Generator[_RowTestInput](
      object is GenObj[_RowTestInput]
        fun generate(rnd: Randomness): _RowTestInput^ =>
          _GenHelper.row_test_input(rnd)
      end)

  fun property(input: _RowTestInput, ph: PropertyHelper) =>
    try
      let result = input.row.text(input.col)?
      match input.expected
      | let v: SqlText =>
        match result
        | let r: String val => ph.assert_eq[String val](v.value, r)
        else ph.fail("expected String, got SqlNull")
        end
      | SqlNull =>
        match result
        | SqlNull => None
        else ph.fail("expected SqlNull")
        end
      else ph.fail("text() should have raised error")
      end
    else
      match input.expected
      | let _: SqlText => ph.fail("text() raised error on SqlText")
      | SqlNull => ph.fail("text() raised error on SqlNull")
      else None
      end
    end

class iso _RowBoolAccessorProperty is Property1[_RowTestInput]
  fun name(): String => "row.bool() returns value for SqlBool, error for others"

  fun gen(): Generator[_RowTestInput] =>
    Generator[_RowTestInput](
      object is GenObj[_RowTestInput]
        fun generate(rnd: Randomness): _RowTestInput^ =>
          _GenHelper.row_test_input(rnd)
      end)

  fun property(input: _RowTestInput, ph: PropertyHelper) =>
    try
      let result = input.row.bool(input.col)?
      match input.expected
      | let v: SqlBool =>
        match result
        | let r: Bool => ph.assert_eq[Bool](v.value, r)
        else ph.fail("expected Bool, got SqlNull")
        end
      | let v: SqlTinyInt =>
        match result
        | let r: Bool => ph.assert_eq[Bool](v.value != 0, r)
        else ph.fail("expected Bool from SqlTinyInt, got SqlNull")
        end
      | let v: SqlSmallInt =>
        match result
        | let r: Bool => ph.assert_eq[Bool](v.value != 0, r)
        else ph.fail("expected Bool from SqlSmallInt, got SqlNull")
        end
      | let v: SqlInteger =>
        match result
        | let r: Bool => ph.assert_eq[Bool](v.value != 0, r)
        else ph.fail("expected Bool from SqlInteger, got SqlNull")
        end
      | let v: SqlBigInt =>
        match result
        | let r: Bool => ph.assert_eq[Bool](v.value != 0, r)
        else ph.fail("expected Bool from SqlBigInt, got SqlNull")
        end
      | let v: SqlText =>
        // bool() now accepts SqlText for boolean-like strings
        match v.value.lower()
        | "1" | "t" | "true" =>
          match result
          | let r: Bool => ph.assert_eq[Bool](true, r)
          else ph.fail("expected true from SqlText, got SqlNull")
          end
        | "0" | "f" | "false" =>
          match result
          | let r: Bool => ph.assert_eq[Bool](false, r)
          else ph.fail("expected false from SqlText, got SqlNull")
          end
        else
          ph.fail("bool() should have raised error for non-boolean SqlText")
        end
      | SqlNull =>
        match result
        | SqlNull => None
        else ph.fail("expected SqlNull")
        end
      else ph.fail("bool() should have raised error")
      end
    else
      match input.expected
      | let _: SqlBool => ph.fail("bool() raised error on SqlBool")
      | let _: SqlTinyInt => ph.fail("bool() raised error on SqlTinyInt")
      | let _: SqlSmallInt => ph.fail("bool() raised error on SqlSmallInt")
      | let _: SqlInteger => ph.fail("bool() raised error on SqlInteger")
      | let _: SqlBigInt => ph.fail("bool() raised error on SqlBigInt")
      | let v: SqlText =>
        // Error is expected for non-boolean text values
        match v.value.lower()
        | "1" | "t" | "true" | "0" | "f" | "false" =>
          ph.fail("bool() raised error on boolean SqlText")
        else None // error is correct for non-boolean text
        end
      | SqlNull => ph.fail("bool() raised error on SqlNull")
      else None
      end
    end

class iso _RowNullProperty is Property1[USize]
  fun name(): String => "row.is_null() is true iff column is SqlNull"

  fun gen(): Generator[USize] =>
    Generators.usize(1, 5)

  fun property(num_cols: USize, ph: PropertyHelper) =>
    let cols = recover iso Array[SqlValue](num_cols) end
    var i: USize = 0
    while i < num_cols do
      if (i % 2) == 0 then cols.push(SqlNull)
      else cols.push(SqlInteger(42))
      end
      i = i + 1
    end
    let row = Row.create(consume cols)

    i = 0
    while i < num_cols do
      try
        let expected_null = (i % 2) == 0
        let actual_null = row.is_null(ColIndex((i + 1).u16()))?
        ph.assert_eq[Bool](expected_null, actual_null)
      else
        ph.fail("is_null raised error for valid column " + (i + 1).string())
      end
      i = i + 1
    end

class val _RowOutOfRangeInput
  let row: Row
  let bad_col: ColIndex

  new val create(row': Row, bad_col': ColIndex) =>
    row = row'
    bad_col = bad_col'

class iso _RowOutOfRangeProperty is Property1[_RowOutOfRangeInput]
  fun name(): String => "row.column() raises error for out-of-range index"

  fun gen(): Generator[_RowOutOfRangeInput] =>
    Generator[_RowOutOfRangeInput](
      object is GenObj[_RowOutOfRangeInput]
        fun generate(rnd: Randomness): _RowOutOfRangeInput^ =>
          let num_cols = rnd.usize(1, 5)
          let cols = recover iso Array[SqlValue](num_cols) end
          var i: USize = 0
          while i < num_cols do cols.push(SqlBigInt(rnd.i64())); i = i + 1 end
          let row = Row.create(consume cols)

          let bad: U16 =
            if rnd.bool() then 0
            else (num_cols + 1 + rnd.usize(0, 10)).u16()
            end
          _RowOutOfRangeInput(row, ColIndex(bad))
      end)

  fun property(input: _RowOutOfRangeInput, ph: PropertyHelper) =>
    try
      input.row.column(input.bad_col)?
      ph.fail("should have raised error for index "
        + input.bad_col.apply().string())
    else None
    end
