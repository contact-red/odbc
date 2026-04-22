class ref _ColumnBindings
  """
  Manages SQLBindCol buffers for a cursor's result set. Created once when
  a cursor opens; SQLFetch writes directly into these buffers.

  Columns whose SQL type isn't natively mapped to a typed SqlValue are
  marked as raw — left unbound here and read on demand via SQLGetData
  with SQL_C_BINARY, surfaced to the user as `SqlRaw`.
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
  // Whether column is raw — unbound, read via SQLGetData on fetch.
  let _is_raw: Array[Bool] ref
  let _opts: OdbcOptions
  let _hstmt: Pointer[None] tag

  new ref create(hstmt: Pointer[None] tag,
    opts: OdbcOptions = OdbcOptions) ? =>
    _hstmt = hstmt
    _opts = opts
    var nc: I16 = 0
    @SQLNumResultCols(hstmt, addressof nc)
    _num_cols = nc.usize()

    _sql_types = Array[I16](_num_cols)
    _c_types = Array[I16](_num_cols)
    _fixed_bufs = Array[Array[U8]](_num_cols)
    _text_bufs = Array[String ref](_num_cols)
    _indicators = Array[I64].init(0, _num_cols)
    _is_text = Array[Bool](_num_cols)
    _is_raw = Array[Bool](_num_cols)

    var col: U16 = 1
    while col <= nc.u16() do
      // Describe column — we only need data_type and col_size,
      // but SQLDescribeCol requires a name buffer
      let name_buf = Array[U8].init(0, 2)
      var name_len: I16 = 0
      var data_type: I16 = 0
      var col_size: U64 = 0
      var decimal_digits: I16 = 0
      var nullable: I16 = 0

      @SQLDescribeCol(
        hstmt,
        col,
        name_buf.cpointer(),
        2,
        addressof name_len,
        addressof data_type,
        addressof col_size,
        addressof decimal_digits,
        addressof nullable)

      _sql_types.push(data_type)

      let pos = (col - 1).usize()

      // Map SQL type to C type
      let c_type: I16 =
        match data_type
        | ODBCConstants.sql_bit() => ODBCConstants.c_bit()
        | ODBCConstants.sql_tinyint() => ODBCConstants.c_stinyint()
        | ODBCConstants.sql_smallint() => ODBCConstants.c_sshort()
        | ODBCConstants.sql_integer() => ODBCConstants.c_slong()
        | ODBCConstants.sql_bigint() => ODBCConstants.c_sbigint()
        | ODBCConstants.sql_real() => ODBCConstants.c_double()
        | ODBCConstants.sql_float() => ODBCConstants.c_double()
        | ODBCConstants.sql_double() => ODBCConstants.c_double()
        | ODBCConstants.sql_char() => ODBCConstants.c_char()
        | ODBCConstants.sql_varchar() => ODBCConstants.c_char()
        | ODBCConstants.sql_longvarchar() => ODBCConstants.c_char()
        | ODBCConstants.sql_type_date() => ODBCConstants.c_type_date()
        | ODBCConstants.sql_type_time() => ODBCConstants.c_type_time()
        | ODBCConstants.sql_type_timestamp() => ODBCConstants.c_type_timestamp()
        | ODBCConstants.sql_numeric() => ODBCConstants.c_char()
        | ODBCConstants.sql_decimal() => ODBCConstants.c_char()
        else
        // Unmapped SQL type — leave unbound; we'll fetch raw bytes via
        // SQLGetData on read and surface as SqlRaw.
        _c_types.push(0)
        _fixed_bufs.push(Array[U8])
        _text_bufs.push(String)
        _is_text.push(false)
        _is_raw.push(true)
        col = col + 1
        continue
      end

      _c_types.push(c_type)
      _is_raw.push(false)

      if c_type == ODBCConstants.c_char() then
        // Text column: allocate buffer based on declared col_size, capped.
        // Floor at 4096 — some drivers report col_size=0 for TEXT/LONGVARCHAR.
        let buf_size =
          (col_size + 1).usize().max(4096).min(_opts.max_column_bytes())
        let tbuf: String ref = String(buf_size)
        var j: USize = 0
        while j < buf_size do tbuf.push(0); j = j + 1 end

        _fixed_bufs.push(Array[U8])
        _text_bufs.push(tbuf)
        _is_text.push(true)

        // Bind the text column
        let rc =
          @SQLBindCol(
          hstmt,
          col,
          c_type,
          tbuf.cpointer(),
          buf_size.i64(),
          _indicators.cpointer(pos))
        if not ODBCConstants.ok(rc) then error end
      else
        // Fixed-width column
        let fsize: USize =
          if c_type == ODBCConstants.c_bit() then 1
          elseif c_type == ODBCConstants.c_type_date() then ODBCConstants.date_struct_size()
          elseif c_type == ODBCConstants.c_type_time() then ODBCConstants.time_struct_size()
          elseif c_type == ODBCConstants.c_type_timestamp() then
            ODBCConstants.timestamp_struct_size()
          elseif c_type == ODBCConstants.c_stinyint() then 1
          elseif c_type == ODBCConstants.c_sshort() then 2
          elseif c_type == ODBCConstants.c_slong() then 4
          else 8 // 8 covers I64 and F64
          end
        let fbuf = Array[U8].init(0, fsize)

        _fixed_bufs.push(fbuf)
        _text_bufs.push(String)
        _is_text.push(false)

        // Bind the fixed column
        let rc =
          @SQLBindCol(
          hstmt,
          col,
          c_type,
          fbuf.cpointer(),
          fsize.i64(),
          _indicators.cpointer(pos))
        if not ODBCConstants.ok(rc) then error end
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
      match \exhaustive\ _read_column_value(i)
      | let sv: SqlValue => columns.push(sv)
      | let e: FetchError => return e
      end
      i = i + 1
    end

    Row.create(consume columns)

  fun ref build_row_into(row: MutableRow): (MutableRow | FetchError) =>
    """
    Overwrite a MutableRow with values from the current fetch.
    Reuses the row object and its column array — no allocation for the
    row container (though SqlText/SqlDecimal values are still allocated
    since they own their string data).
    """
    row._clear()

    var i: USize = 0
    while i < _num_cols do
      match \exhaustive\ _read_column_value(i)
      | let sv: SqlValue => row._push(sv)
      | let e: FetchError => return e
      end
      i = i + 1
    end

    row

  fun ref _read_column_value(i: USize): (SqlValue | FetchError) =>
    """
    Read the SqlValue for column i from the bound buffers.
    """
    try
      if _is_raw(i)? then
        return _read_raw(i)
      end

      let ind = _indicators(i)?

      if ind == ODBCConstants.sql_null_data() then
        return SqlNull
      elseif _is_text(i)? then
        let tbuf = _text_bufs(i)?
        let len = ind.usize()

        // If data fits in bound buffer, read directly.
        // Otherwise fall back to SQLGetData for the full value.
        var text: String val = ""
        if len < tbuf.size() then
          text = tbuf.substring(0, len.isize())
        else
          match \exhaustive\ _get_long_text(i)
          | let s: String val => text = s
          | let e: FetchError => return e
          end
        end

        let sql_type = _sql_types(i)?
        if (sql_type == ODBCConstants.sql_numeric())
          or (sql_type == ODBCConstants.sql_decimal())
        then
          return SqlDecimal(text)
        else
          if _opts.validate_utf8 and (not _is_valid_utf8(text)) then
            return FetchError(InvalidUtf8)
          end
          return SqlText(text)
        end
      else
        let fbuf = _fixed_bufs(i)?
        let c_type = _c_types(i)?

        if c_type == ODBCConstants.c_stinyint() then
          return _SqlTinyIntDecode(fbuf)
        elseif c_type == ODBCConstants.c_sshort() then
          return _SqlSmallIntDecode(fbuf)
        elseif c_type == ODBCConstants.c_slong() then
          return _SqlIntegerDecode(fbuf)
        elseif c_type == ODBCConstants.c_sbigint() then
          return _SqlBigIntDecode(fbuf)
        elseif c_type == ODBCConstants.c_double() then
          return _SqlFloatDecode(fbuf)
        elseif c_type == ODBCConstants.c_bit() then
          return _SqlBoolDecode(fbuf)
        elseif c_type == ODBCConstants.c_type_date() then
          return _SqlDateDecode(fbuf)
        elseif c_type == ODBCConstants.c_type_time() then
          return _SqlTimeDecode(fbuf)
        elseif c_type == ODBCConstants.c_type_timestamp() then
          return _SqlTimestampDecode(fbuf)
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
          if (s(byte_i)? != 0xEF)
            or (s(byte_i + 1)? != 0xBF)
            or (s(byte_i + 2)? != 0xBD)
          then
            return false
          end
        end
        byte_i = byte_i + width.usize()
      end
      true
    else
      false
    end

  fun ref _get_long_text(i: USize): (String val | FetchError) =>
    """
    Retrieve full text for column i when the bound buffer was too small.

    Discards the partial head already written into the bound buffer and
    reads the whole value via a single SQLGetData call into a freshly
    allocated buffer sized to the full length. psqlODBC returns the full
    column value from byte 0 on SQLGetData regardless of prior bind
    progress, so reassembling head+tail is unsafe — the "tail" bytes are
    actually a duplicate of the prefix.
    """
    try
      let total_len = _indicators(i)?.usize()
      if total_len > _opts.max_column_bytes() then
        return FetchError(ColumnTooLarge)
      end

      let buf: String ref = String(total_len + 1)
      var j: USize = 0
      while j < (total_len + 1) do buf.push(0); j = j + 1 end

      var ind: I64 = 0
      let rc =
        @SQLGetData(
        _hstmt,
        (i + 1).u16(),
        ODBCConstants.c_char(),
        buf.cpointer(),
        (total_len + 1).i64(),
        addressof ind)

      if not ODBCConstants.ok(rc) then
        return FetchError(DriverFetchError)
      end

      let len: USize =
        if ind == ODBCConstants.sql_null_data() then 0
        elseif ind < 0 then 0
        else ind.usize().min(total_len)
        end
      buf.substring(0, len.isize())
    else
      FetchError(DriverFetchError)
    end

  fun ref _read_raw(i: USize): (SqlValue | FetchError) =>
    """
    Fetch a raw column via SQLGetData (column was unbound at execute time).
    Two-pass: probe with a 1-byte buffer to learn the length and null
    state, then allocate exactly and re-fetch.

    NULL cells return `SqlNull`, matching the convention for typed
    columns. Non-null cells return `SqlRaw` carrying the original SQL
    type code, the bytes, and the indicator.
    """
    try
      var probe_byte: U8 = 0
      var probe_ind: I64 = 0
      let rc1 =
        @SQLGetData(
        _hstmt,
        (i + 1).u16(),
        ODBCConstants.c_binary(),
        addressof probe_byte,
        I64(1),
        addressof probe_ind)

      if (not ODBCConstants.ok(rc1)) and (not ODBCConstants.has_info(rc1)) then
        return FetchError(DriverFetchError)
      end

      if probe_ind == ODBCConstants.sql_null_data() then
        return SqlNull
      end

      // Indicator < 0 (other than SQL_NULL_DATA) means SQL_NO_TOTAL or
      // similar — we can't size the buffer, so treat as fetch error.
      if probe_ind < 0 then
        return FetchError(DriverFetchError)
      end

      let total_len = probe_ind.usize()
      if total_len > _opts.max_column_bytes() then
        return FetchError(ColumnTooLarge)
      end

      let sql_type = _sql_types(i)?

      if total_len == 0 then
        return SqlRaw(sql_type, recover val Array[U8] end, 0)
      end

      // Allocate exact size (iso so we can consume to val), re-fetch.
      let buf = recover iso Array[U8].init(0, total_len) end
      var ind: I64 = 0
      let rc2 =
        @SQLGetData(
        _hstmt,
        (i + 1).u16(),
        ODBCConstants.c_binary(),
        buf.cpointer(),
        total_len.i64(),
        addressof ind)

      if not ODBCConstants.ok(rc2) then
        return FetchError(DriverFetchError)
      end

      SqlRaw(sql_type, consume buf, ind)
    else
      FetchError(DriverFetchError)
    end

  fun num_cols(): USize => _num_cols
