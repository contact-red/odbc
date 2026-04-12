class ref _ColumnBindings
  """
  Manages SQLBindCol buffers for a cursor's result set. Created once when
  a cursor opens; SQLFetch writes directly into these buffers.
  """

  let _num_cols: USize
  // Per-column metadata
  let _sql_types: Array[I16] ref
  let _c_types: Array[I16] ref
  // Per-column buffers for fixed-width types (I64, F64, U8)
  let _fixed_bufs: Array[Array[U8]] ref
  // Per-column buffers for text
  let _text_bufs: Array[String ref] ref
  // Per-column indicator (SQL_NULL_DATA or byte length)
  let _indicators: Array[I64] ref
  // Whether column is text (needs text_buf) or fixed (needs fixed_buf)
  let _is_text: Array[Bool] ref
  // Whether column type is unsupported
  let _is_unsupported: Array[Bool] ref
  let _validate_utf8: Bool

  new ref create(hstmt: Pointer[None] tag,
    validate_utf8: Bool = true) ? =>
    _validate_utf8 = validate_utf8
    var nc: I16 = 0
    @SQLNumResultCols(hstmt, addressof nc)
    _num_cols = nc.usize()

    _sql_types = Array[I16](_num_cols)
    _c_types = Array[I16](_num_cols)
    _fixed_bufs = Array[Array[U8]](_num_cols)
    _text_bufs = Array[String ref](_num_cols)
    _indicators = Array[I64].init(0, _num_cols)
    _is_text = Array[Bool](_num_cols)
    _is_unsupported = Array[Bool](_num_cols)

    var col: U16 = 1
    while col <= nc.u16() do
      // Describe column
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

      _sql_types.push(data_type)

      let pos = (col - 1).usize()

      // Map SQL type to C type
      let c_type: I16 = match data_type
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
      | _ODBC.sql_type_date() => _ODBC.c_type_date()
      | _ODBC.sql_type_time() => _ODBC.c_type_time()
      | _ODBC.sql_type_timestamp() => _ODBC.c_type_timestamp()
      | _ODBC.sql_numeric() => _ODBC.c_char()  // read as string
      | _ODBC.sql_decimal() => _ODBC.c_char()  // read as string
      else
        // Unsupported type — don't bind, will produce FetchError
        _c_types.push(0)
        _fixed_bufs.push(Array[U8])
        _text_bufs.push(String)
        _is_text.push(false)
        _is_unsupported.push(true)
        col = col + 1
        continue
      end

      _c_types.push(c_type)
      _is_unsupported.push(false)

      if c_type == _ODBC.c_char() then
        // Text column: allocate buffer based on declared col_size, capped
        let buf_size = (col_size + 1).usize().min(16_777_216) // 16 MB
        let tbuf: String ref = String(buf_size)
        j = 0
        while j < buf_size do tbuf.push(0); j = j + 1 end

        _fixed_bufs.push(Array[U8])
        _text_bufs.push(tbuf)
        _is_text.push(true)

        // Bind the text column
        let rc = @SQLBindCol(hstmt, col, c_type,
          tbuf.cpointer(), buf_size.i64(),
          _indicators.cpointer(pos))
        if not _ODBC.ok(rc) then error end
      else
        // Fixed-width column
        let fsize: USize = if c_type == _ODBC.c_bit() then 1
        elseif c_type == _ODBC.c_type_date() then _ODBC.date_struct_size()
        elseif c_type == _ODBC.c_type_time() then _ODBC.time_struct_size()
        elseif c_type == _ODBC.c_type_timestamp() then _ODBC.timestamp_struct_size()
        else 8 end // 8 covers I64 and F64
        let fbuf = Array[U8].init(0, fsize)

        _fixed_bufs.push(fbuf)
        _text_bufs.push(String)
        _is_text.push(false)

        // Bind the fixed column
        let rc = @SQLBindCol(hstmt, col, c_type,
          fbuf.cpointer(), fsize.i64(),
          _indicators.cpointer(pos))
        if not _ODBC.ok(rc) then error end
      end

      col = col + 1
    end

  fun ref build_row(): (Row | FetchError) =>
    """
    Build a Row val from the already-fetched bound buffers.
    Called after SQLFetch has written into the bound column buffers.
    """
    let columns = recover iso Array[SqlValue](_num_cols) end

    var i: USize = 0
    while i < _num_cols do
      try
        if _is_unsupported(i)? then
          return FetchError(UnsupportedColumnType)
        end

        let ind = _indicators(i)?

        if ind == _ODBC.sql_null_data() then
          columns.push(SqlNull)
        elseif _is_text(i)? then
          let tbuf = _text_bufs(i)?
          let len = ind.usize()
          let text: String val = tbuf.substring(0, len.isize())

          // Numeric/decimal → SqlDecimal; otherwise → SqlText
          let sql_type = _sql_types(i)?
          if (sql_type == _ODBC.sql_numeric())
            or (sql_type == _ODBC.sql_decimal())
          then
            columns.push(SqlDecimal(text))
          else
            if _validate_utf8 and (not _is_valid_utf8(text)) then
              return FetchError(InvalidUtf8)
            end
            columns.push(SqlText(text))
          end
        else
          // Fixed-width: read from fixed buffer
          let fbuf = _fixed_bufs(i)?
          let c_type = _c_types(i)?

          if c_type == _ODBC.c_sbigint() then
            var value: I64 = 0
            @memcpy(addressof value, fbuf.cpointer(), 8)
            columns.push(SqlInt(value))
          elseif c_type == _ODBC.c_double() then
            var value: F64 = 0
            @memcpy(addressof value, fbuf.cpointer(), 8)
            columns.push(SqlFloat(value))
          elseif c_type == _ODBC.c_bit() then
            columns.push(SqlBool(try fbuf(0)? != 0 else false end))
          elseif c_type == _ODBC.c_type_date() then
            // DATE_STRUCT: year(I16@0), month(U16@2), day(U16@4)
            var yr: I16 = 0; var mo: U16 = 0; var dy: U16 = 0
            @memcpy(addressof yr, fbuf.cpointer(), 2)
            @memcpy(addressof mo, fbuf.cpointer(2), 2)
            @memcpy(addressof dy, fbuf.cpointer(4), 2)
            columns.push(SqlDate(yr, mo, dy))
          elseif c_type == _ODBC.c_type_time() then
            // TIME_STRUCT: hour(U16@0), minute(U16@2), second(U16@4)
            var hr: U16 = 0; var mi: U16 = 0; var se: U16 = 0
            @memcpy(addressof hr, fbuf.cpointer(), 2)
            @memcpy(addressof mi, fbuf.cpointer(2), 2)
            @memcpy(addressof se, fbuf.cpointer(4), 2)
            columns.push(SqlTime(hr, mi, se))
          elseif c_type == _ODBC.c_type_timestamp() then
            // TIMESTAMP_STRUCT: year(I16@0), month(U16@2), day(U16@4),
            //   hour(U16@6), minute(U16@8), second(U16@10), fraction(U32@12)
            var yr: I16 = 0; var mo: U16 = 0; var dy: U16 = 0
            var hr: U16 = 0; var mi: U16 = 0; var se: U16 = 0
            var fr: U32 = 0
            @memcpy(addressof yr, fbuf.cpointer(), 2)
            @memcpy(addressof mo, fbuf.cpointer(2), 2)
            @memcpy(addressof dy, fbuf.cpointer(4), 2)
            @memcpy(addressof hr, fbuf.cpointer(6), 2)
            @memcpy(addressof mi, fbuf.cpointer(8), 2)
            @memcpy(addressof se, fbuf.cpointer(10), 2)
            @memcpy(addressof fr, fbuf.cpointer(12), 4)
            columns.push(SqlTimestamp(yr, mo, dy, hr, mi, se, fr))
          end
        end
      else
        return FetchError(DriverFetchError)
      end
      i = i + 1
    end

    Row.create(consume columns)

  fun ref build_row_into(row: MutableRow): (MutableRow | FetchError) =>
    """
    Overwrite a MutableRow with values from the current fetch.
    Reuses the row object — no allocation for the row itself or its
    column array (though SqlText/SqlDecimal values are still allocated
    since they own their string data).
    """
    let columns = Array[SqlValue](_num_cols)

    var i: USize = 0
    while i < _num_cols do
      match _read_column_value(i)
      | let sv: SqlValue => columns.push(sv)
      | let e: FetchError => return e
      end
      i = i + 1
    end

    row._set_columns(columns)
    row

  fun ref _read_column_value(i: USize): (SqlValue | FetchError) =>
    """
    Read the SqlValue for column i from the bound buffers.
    """
    try
      if _is_unsupported(i)? then
        return FetchError(UnsupportedColumnType)
      end

      let ind = _indicators(i)?

      if ind == _ODBC.sql_null_data() then
        return SqlNull
      elseif _is_text(i)? then
        let tbuf = _text_bufs(i)?
        let len = ind.usize()
        let text: String val = tbuf.substring(0, len.isize())

        let sql_type = _sql_types(i)?
        if (sql_type == _ODBC.sql_numeric())
          or (sql_type == _ODBC.sql_decimal())
        then
          return SqlDecimal(text)
        else
          if _validate_utf8 and (not _is_valid_utf8(text)) then
            return FetchError(InvalidUtf8)
          end
          return SqlText(text)
        end
      else
        let fbuf = _fixed_bufs(i)?
        let c_type = _c_types(i)?

        if c_type == _ODBC.c_sbigint() then
          var value: I64 = 0
          @memcpy(addressof value, fbuf.cpointer(), 8)
          return SqlInt(value)
        elseif c_type == _ODBC.c_double() then
          var value: F64 = 0
          @memcpy(addressof value, fbuf.cpointer(), 8)
          return SqlFloat(value)
        elseif c_type == _ODBC.c_bit() then
          return SqlBool(try fbuf(0)? != 0 else false end)
        elseif c_type == _ODBC.c_type_date() then
          var yr: I16 = 0; var mo: U16 = 0; var dy: U16 = 0
          @memcpy(addressof yr, fbuf.cpointer(), 2)
          @memcpy(addressof mo, fbuf.cpointer(2), 2)
          @memcpy(addressof dy, fbuf.cpointer(4), 2)
          return SqlDate(yr, mo, dy)
        elseif c_type == _ODBC.c_type_time() then
          var hr: U16 = 0; var mi: U16 = 0; var se: U16 = 0
          @memcpy(addressof hr, fbuf.cpointer(), 2)
          @memcpy(addressof mi, fbuf.cpointer(2), 2)
          @memcpy(addressof se, fbuf.cpointer(4), 2)
          return SqlTime(hr, mi, se)
        elseif c_type == _ODBC.c_type_timestamp() then
          var yr: I16 = 0; var mo: U16 = 0; var dy: U16 = 0
          var hr: U16 = 0; var mi: U16 = 0; var se: U16 = 0
          var fr: U32 = 0
          @memcpy(addressof yr, fbuf.cpointer(), 2)
          @memcpy(addressof mo, fbuf.cpointer(2), 2)
          @memcpy(addressof dy, fbuf.cpointer(4), 2)
          @memcpy(addressof hr, fbuf.cpointer(6), 2)
          @memcpy(addressof mi, fbuf.cpointer(8), 2)
          @memcpy(addressof se, fbuf.cpointer(10), 2)
          @memcpy(addressof fr, fbuf.cpointer(12), 4)
          return SqlTimestamp(yr, mo, dy, hr, mi, se, fr)
        end
      end
    end
    FetchError(DriverFetchError)

  fun _is_valid_utf8(s: String box): Bool =>
    """
    Validate UTF-8 by checking that Pony can iterate the codepoints
    without encountering replacement characters where none were in
    the original bytes.
    """
    try
      var byte_i: USize = 0
      while byte_i < s.size() do
        (let cp, let width) = s.utf32(byte_i.isize())?
        if width == 0 then return false end
        // 0xFFFD is the replacement character — if we see it but the bytes
        // aren't actually 0xEF 0xBF 0xBD, the data is invalid
        if (cp == 0xFFFD) and (width != 3) then return false end
        if (cp == 0xFFFD) and (width == 3) then
          // Could be a real replacement character — check bytes
          if (s(byte_i)? != 0xEF) or
             (s(byte_i + 1)? != 0xBF) or
             (s(byte_i + 2)? != 0xBD) then
            return false
          end
        end
        byte_i = byte_i + width.usize()
      end
      true
    else
      false
    end

  fun num_cols(): USize => _num_cols
