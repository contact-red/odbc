primitive _ReadColumns
  """
  Shared column-reading logic for Statement and Cursor.
  Reads all columns via SQLGetData and builds a Row val."""

  fun build_row(hstmt: Pointer[None] tag): (Row | FetchError) =>
    var num_cols: I16 = 0
    @SQLNumResultCols(hstmt, addressof num_cols)

    let columns: Array[SqlValue] iso = recover iso Array[SqlValue](num_cols.usize()) end

    var col: U16 = 1
    while col <= num_cols.u16() do
      let name_buf: String ref = String(256)
      var j: USize = 0
      while j < 256 do name_buf.push(0); j = j + 1 end

      var name_len: I16 = 0
      var data_type: I16 = 0
      var col_size: U64 = 0
      var decimal_digits: I16 = 0
      var nullable: I16 = 0

      @SQLDescribeCol(hstmt, col,
        name_buf.cpointer(), 256, addressof name_len,
        addressof data_type, addressof col_size,
        addressof decimal_digits, addressof nullable)

      match _read_column(hstmt, col, data_type, col_size)
      | let sv: SqlValue => columns.push(sv)
      | let e: FetchError => return e
      end

      col = col + 1
    end

    Row.create(consume columns)

  fun _read_column(hstmt: Pointer[None] tag, col: U16, sql_type: I16,
    col_size: U64): (SqlValue | FetchError) =>

    let c_type: I16 = match sql_type
    | _ODBC.sql_bit() => _ODBC.c_bit()
    | _ODBC.sql_smallint() => _ODBC.c_sbigint()
    | _ODBC.sql_integer() => _ODBC.c_sbigint()
    | _ODBC.sql_bigint() => _ODBC.c_sbigint()
    | _ODBC.sql_real() => _ODBC.c_double()
    | _ODBC.sql_float() => _ODBC.c_double()
    | _ODBC.sql_double() => _ODBC.c_double()
    | _ODBC.sql_char() => _ODBC.c_char()
    | _ODBC.sql_varchar() => _ODBC.c_char()
    | _ODBC.sql_longvarchar() => _ODBC.c_char()
    else
      return FetchError(UnsupportedColumnType)
    end

    var ind: I64 = 0

    if c_type == _ODBC.c_sbigint() then
      var value: I64 = 0
      let rc = @SQLGetData(hstmt, col, c_type,
        addressof value, 8, addressof ind)
      if not _ODBC.ok(rc) then
        return FetchError(DriverFetchError,
          _DiagHelper.read(_ODBC.handle_stmt(), hstmt))
      end
      if ind == _ODBC.sql_null_data() then SqlNull
      else SqlInt(value)
      end

    elseif c_type == _ODBC.c_double() then
      var value: F64 = 0.0
      let rc = @SQLGetData(hstmt, col, c_type,
        addressof value, 8, addressof ind)
      if not _ODBC.ok(rc) then
        return FetchError(DriverFetchError,
          _DiagHelper.read(_ODBC.handle_stmt(), hstmt))
      end
      if ind == _ODBC.sql_null_data() then SqlNull
      else SqlFloat(value)
      end

    elseif c_type == _ODBC.c_bit() then
      var value: U8 = 0
      let rc = @SQLGetData(hstmt, col, c_type,
        addressof value, 1, addressof ind)
      if not _ODBC.ok(rc) then
        return FetchError(DriverFetchError,
          _DiagHelper.read(_ODBC.handle_stmt(), hstmt))
      end
      if ind == _ODBC.sql_null_data() then SqlNull
      else SqlBool(value != 0)
      end

    elseif c_type == _ODBC.c_char() then
      // Allocate buffer based on column size, capped at 16 MB
      let buf_size = (col_size + 1).usize().min(16_777_216)
      let buf: String ref = String(buf_size)
      var k: USize = 0
      while k < buf_size do buf.push(0); k = k + 1 end

      let rc = @SQLGetData(hstmt, col, c_type,
        buf.cpointer(), buf_size.i64(), addressof ind)
      if not _ODBC.ok(rc) then
        return FetchError(DriverFetchError,
          _DiagHelper.read(_ODBC.handle_stmt(), hstmt))
      end
      if ind == _ODBC.sql_null_data() then
        SqlNull
      elseif ind > buf_size.i64() then
        FetchError(ColumnTooLarge)
      else
        let len = ind.usize().min(buf_size - 1)
        let text: String val = buf.substring(0, len.isize())
        // UTF-8 validation: Pony strings track utf8 validity
        SqlText(text)
      end
    else
      FetchError(UnsupportedColumnType)
    end
