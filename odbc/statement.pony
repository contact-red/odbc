class ref Statement
  """
  Non-sendable prepared statement wrapping SQLHSTMT. Reusable: bind,
  execute, fetch, close_cursor, rebind, re-execute.
  """

  var _hstmt: Pointer[None] tag
  let _param_count: U16
  let _conn_alive: _AliveFlag ref
  var _closed: Bool
  var _cursor_open: Bool
  var _last_warnings: (Warnings | None)
  let _bound_flags: Array[Bool] ref
  let _param_bufs: Array[Array[U8]] ref
  let _param_inds: Array[I64] ref
  let _param_c_types: Array[I16] ref
  var _params_bound_to_odbc: Bool
  var _needs_rebind: Bool
  var _col_bindings: (_ColumnBindings | None)
  let _validate_utf8: Bool

  new ref _create(
    hstmt: Pointer[None] tag,
    param_count: U16,
    conn_alive: _AliveFlag ref,
    validate_utf8: Bool = true)
  =>
    _hstmt = hstmt
    _param_count = param_count
    _conn_alive = conn_alive
    _closed = false
    _cursor_open = false
    _last_warnings = None
    _params_bound_to_odbc = false
    _needs_rebind = false
    _col_bindings = None
    _validate_utf8 = validate_utf8

    let n = param_count.usize()
    _bound_flags = Array[Bool].init(false, n)
    _param_bufs = Array[Array[U8]](n)
    _param_inds = Array[I64].init(0, n)
    _param_c_types = Array[I16].init(0, n)
    var i: USize = 0
    while i < n do
      _param_bufs.push(Array[U8].init(0, 8))
      i = i + 1
    end

  fun ref _check_alive(): (None | ExecError) =>
    if _closed then
      return ExecError(
        StatementClosed, recover val Array[DiagRecord] end)
    end
    if not _conn_alive.is_alive() then
      return ExecError(
        ConnectionClosed, recover val Array[DiagRecord] end)
    end
    None

  fun ref bind(i: ParamIndex, v: SqlValue): (Bound | BindError) =>
    """
    Write value into parameter scratch slot. Atomic per param.
    """
    match _check_alive()
    | let _: ExecError =>
      return BindError(ParamIndexOutOfRange, i)
    end

    let idx = i.apply()
    if (idx == 0) or (idx > _param_count) then
      return BindError(ParamIndexOutOfRange, i)
    end

    let pos = (idx - 1).usize()

    try
      let buf = _param_bufs(pos)?

      match \exhaustive\ v
      | SqlNull =>
        _param_inds(pos)? = _ODBC.sql_null_data()
        _param_c_types(pos)? = _ODBC.c_char()
      | let sv: SqlBool =>
        buf(0)? = if sv.value then 1 else 0 end
        _param_inds(pos)? = 1
        _param_c_types(pos)? = _ODBC.c_bit()
      | let sv: SqlInt =>
        var n = sv.value
        @memcpy(buf.cpointer(), addressof n, 8)
        _param_inds(pos)? = 0
        _param_c_types(pos)? = _ODBC.c_sbigint()
      | let sv: SqlFloat =>
        var n = sv.value
        @memcpy(buf.cpointer(), addressof n, 8)
        _param_inds(pos)? = 0
        _param_c_types(pos)? = _ODBC.c_double()
      | let sv: SqlText =>
        let bytes = sv.value
        let needed = bytes.size()
        if needed > buf.size() then
          let new_buf = Array[U8].init(0, needed)
          _param_bufs(pos)? = new_buf
          @memcpy(new_buf.cpointer(), bytes.cpointer(), needed)
          _needs_rebind = true  // buffer address changed
        else
          @memcpy(buf.cpointer(), bytes.cpointer(), needed)
        end
        _param_inds(pos)? = needed.i64()
        _param_c_types(pos)? = _ODBC.c_char()
      | let sv: SqlDate =>
        var yr = sv.year; var mo = sv.month; var dy = sv.day
        @memcpy(buf.cpointer(), addressof yr, 2)
        @memcpy(buf.cpointer(2), addressof mo, 2)
        @memcpy(buf.cpointer(4), addressof dy, 2)
        _param_inds(pos)? = 0
        _param_c_types(pos)? = _ODBC.c_type_date()
      | let sv: SqlTime =>
        var hr = sv.hour; var mi = sv.minute; var se = sv.second
        @memcpy(buf.cpointer(), addressof hr, 2)
        @memcpy(buf.cpointer(2), addressof mi, 2)
        @memcpy(buf.cpointer(4), addressof se, 2)
        _param_inds(pos)? = 0
        _param_c_types(pos)? = _ODBC.c_type_time()
      | let sv: SqlTimestamp =>
        let needed: USize = _ODBC.timestamp_struct_size()
        let tbuf =
          if needed > buf.size() then
            let new_buf = Array[U8].init(0, needed)
            _param_bufs(pos)? = new_buf
            _needs_rebind = true
            new_buf
          else
            buf
          end
        var yr = sv.year; var mo = sv.month; var dy = sv.day
        var hr = sv.hour; var mi = sv.minute; var se = sv.second
        var fr = sv.fraction
        @memcpy(tbuf.cpointer(), addressof yr, 2)
        @memcpy(tbuf.cpointer(2), addressof mo, 2)
        @memcpy(tbuf.cpointer(4), addressof dy, 2)
        @memcpy(tbuf.cpointer(6), addressof hr, 2)
        @memcpy(tbuf.cpointer(8), addressof mi, 2)
        @memcpy(tbuf.cpointer(10), addressof se, 2)
        @memcpy(tbuf.cpointer(12), addressof fr, 4)
        _param_inds(pos)? = 0
        _param_c_types(pos)? = _ODBC.c_type_timestamp()
      | let sv: SqlDecimal =>
        let bytes = sv.value
        let needed = bytes.size()
        if needed > buf.size() then
          let new_buf = Array[U8].init(0, needed)
          _param_bufs(pos)? = new_buf
          @memcpy(new_buf.cpointer(), bytes.cpointer(), needed)
          _needs_rebind = true
        else
          @memcpy(buf.cpointer(), bytes.cpointer(), needed)
        end
        _param_inds(pos)? = needed.i64()
        _param_c_types(pos)? = _ODBC.c_char()
      end

      _bound_flags(pos)? = true
    else
      return BindError(ParamIndexOutOfRange, i)
    end
    Bound

  fun ref bind_null(i: ParamIndex): (Bound | BindError) =>
    bind(i, SqlNull)

  fun ref bind_p(i: ParamIndex, v: SqlValue) ? =>
    """
    Partial variant of bind(). Raises error on failure.
    """
    match bind(i, v)
    | let _: BindError => error
    end

  fun ref bind_null_p(i: ParamIndex) ? =>
    """
    Partial variant of bind_null(). Raises error on failure.
    """
    match bind_null(i)
    | let _: BindError => error
    end

  fun ref execute(): (Executed | ExecError) =>
    """
    Execute a prepared SELECT, opening a cursor.
    """
    match _check_alive()
    | let e: ExecError => return e
    end
    if _cursor_open then
      return ExecError(
        CursorAlreadyOpen, recover val Array[DiagRecord] end)
    end

    match _check_all_bound()
    | let e: ExecError => return e
    end

    match _bind_params_to_odbc()
    | let e: ExecError => return e
    end

    let rc = @SQLExecute(_hstmt)
    _last_warnings =
      if _ODBC.has_info(rc) then
        Warnings(_DiagHelper.read(_ODBC.handle_stmt(), _hstmt))
      else
        None
      end

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_stmt(), _hstmt)
      return ExecError(ExecErrorClassifier.classify(diag), diag)
    end

    // Set up column bindings for fetching
    try
      _col_bindings = _ColumnBindings(_hstmt, _validate_utf8)?
    else
      // Column binding failed — close the driver-level cursor so the
      // statement can be reused via close_cursor() / re-execute.
      @SQLFreeStmt(_hstmt, _ODBC.sql_close_cursor())
      let diag = _DiagHelper.read(_ODBC.handle_stmt(), _hstmt)
      return ExecError(ExecErrorClassifier.classify(diag), diag)
    end

    _cursor_open = true
    Executed

  fun ref execute_update(): (RowCount | ExecError) =>
    """
    Execute a prepared DML. Returns affected row count.
    """
    match _check_alive()
    | let e: ExecError => return e
    end
    if _cursor_open then
      return ExecError(
        CursorAlreadyOpen, recover val Array[DiagRecord] end)
    end

    match _check_all_bound()
    | let e: ExecError => return e
    end

    match _bind_params_to_odbc()
    | let e: ExecError => return e
    end

    let rc = @SQLExecute(_hstmt)
    _last_warnings =
      if _ODBC.has_info(rc) then
        Warnings(_DiagHelper.read(_ODBC.handle_stmt(), _hstmt))
      else
        None
      end

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_stmt(), _hstmt)
      return ExecError(ExecErrorClassifier.classify(diag), diag)
    end

    var row_count: I64 = 0
    @SQLRowCount(_hstmt, addressof row_count)
    if row_count == _ODBC.sql_no_row_count() then
      NoRowCount
    else
      row_count.usize()
    end

  fun ref _check_all_bound(): (None | ExecError) =>
    if _param_count == 0 then return None end
    var i: USize = 0
    while i < _param_count.usize() do
      try
        if not _bound_flags(i)? then
          return ExecError(
            UnboundParams,
            recover val Array[DiagRecord] end)
        end
      end
      i = i + 1
    end
    None

  fun ref _bind_params_to_odbc(): (None | ExecError) =>
    """
    Bind-once: call SQLBindParameter on first execute, then only when
    a text buffer was reallocated (dirty flag).
    """
    if _params_bound_to_odbc and (not _needs_rebind) then return None end
    if _param_count == 0 then return None end

    var i: USize = 0
    while i < _param_count.usize() do
      // On first bind, bind all. On rebind, only bind dirty (text that grew).
      // For simplicity in v1, rebind all on dirty — the cost is N FFI calls
      // which only happens when a text param grew.
      try
        let buf = _param_bufs(i)?
        let ind = _param_inds(i)?
        let c_type = _param_c_types(i)?
        let param_num = (i + 1).u16()

        let sql_type: I16 =
          match c_type
          | _ODBC.c_bit() => _ODBC.sql_bit()
          | _ODBC.c_sbigint() => _ODBC.sql_bigint()
          | _ODBC.c_double() => _ODBC.sql_double()
          | _ODBC.c_type_date() => _ODBC.sql_type_date()
          | _ODBC.c_type_time() => _ODBC.sql_type_time()
          | _ODBC.c_type_timestamp() => _ODBC.sql_type_timestamp()
          else _ODBC.sql_varchar()
          end

        let col_size: U64 =
          if c_type == _ODBC.c_char() then
            if ind > 0 then ind.u64() else 1 end
          else
            0
          end

        let rc =
          @SQLBindParameter(
          _hstmt,
          param_num,
          _ODBC.sql_param_input(),
          c_type,
          sql_type,
          col_size,
          0,
          buf.cpointer(),
          buf.size().i64(),
          _param_inds.cpointer(i))

        if not _ODBC.ok(rc) then
          let diag = _DiagHelper.read(_ODBC.handle_stmt(), _hstmt)
          return ExecError(ExecErrorClassifier.classify(diag), diag)
        end
      end
      i = i + 1
    end

    _params_bound_to_odbc = true
    _needs_rebind = false
    None

  fun ref fetch(): (Row | EndOfRows | FetchError) =>
    """
    Fetch the next row. Row is a val snapshot.
    """
    if _closed then return FetchError(CursorClosed) end
    if not _conn_alive.is_alive() then
      return FetchError(FetchConnectionClosed)
    end
    if not _cursor_open then return FetchError(CursorClosed) end

    let rc = @SQLFetch(_hstmt)

    if rc == _ODBC.sql_no_data() then
      return EndOfRows
    end

    _last_warnings =
      if _ODBC.has_info(rc) then
        Warnings(_DiagHelper.read(_ODBC.handle_stmt(), _hstmt))
      else
        None
      end

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_stmt(), _hstmt)
      return FetchError(DriverFetchError, diag)
    end

    // Build Row from bound column buffers (SQLFetch already wrote into them)
    match _col_bindings
    | let cb: _ColumnBindings => cb.build_row()
    else FetchError(DriverFetchError)
    end

  fun ref execute_p() ? =>
    """
    Partial variant of execute(). Raises error on failure.
    """
    match execute()
    | let _: ExecError => error
    end

  fun ref execute_update_p(): RowCount ? =>
    """
    Partial variant of execute_update(). Raises error on failure.
    """
    match \exhaustive\ execute_update()
    | let rc: RowCount => rc
    | let _: ExecError => error
    end

  fun ref fetch_into(row: MutableRow): (MutableRow | EndOfRows | FetchError) =>
    """
    Fetch the next row into a reusable MutableRow. Zero allocation for
    the row container (SqlText/SqlDecimal values still allocate strings).
    """
    if _closed then return FetchError(CursorClosed) end
    if not _conn_alive.is_alive() then
      return FetchError(FetchConnectionClosed)
    end
    if not _cursor_open then return FetchError(CursorClosed) end

    let rc = @SQLFetch(_hstmt)

    if rc == _ODBC.sql_no_data() then
      return EndOfRows
    end

    _last_warnings =
      if _ODBC.has_info(rc) then
        Warnings(_DiagHelper.read(_ODBC.handle_stmt(), _hstmt))
      else
        None
      end

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_stmt(), _hstmt)
      return FetchError(DriverFetchError, diag)
    end

    match _col_bindings
    | let cb: _ColumnBindings => cb.build_row_into(row)
    else FetchError(DriverFetchError)
    end

  fun ref values(): StatementIterator =>
    """
    Return an iterator for use with Pony's `for` loop.
    Yields (Row val | FetchError) — match on each result.
    """
    StatementIterator(this)

  fun cancel_token(): CancelToken =>
    """
    Return a sendable token that can cancel this statement's
    in-progress operation from another actor.

    The token captures a raw copy of the SQLHSTMT pointer. It does not
    track whether the statement has been closed. Calling cancel() on a
    token after close() invokes SQLCancel on a freed handle — undefined
    behavior. The caller must ensure all outstanding tokens are discarded
    before calling close().
    """
    CancelToken(_hstmt)

  fun ref close_cursor() =>
    """
    Close cursor, keep statement for rebinding and re-execution.
    Unbinds columns so they can be rebound on next execute.
    """
    if _cursor_open then
      @SQLFreeStmt(_hstmt, _ODBC.sql_close_cursor())
      @SQLFreeStmt(_hstmt, _ODBC.sql_unbind())
      _cursor_open = false
      _col_bindings = None
    end

  fun ref last_warnings(): (Warnings | None) =>
    _last_warnings

  fun ref close() =>
    """
    Free the SQLHSTMT. Idempotent.

    Any CancelTokens obtained from cancel_token() become invalid after
    this call. Using a token after close() is undefined behavior — see
    cancel_token() for the lifetime contract.
    """
    if _closed then return end
    if _cursor_open then
      @SQLFreeStmt(_hstmt, _ODBC.sql_close_cursor())
      _cursor_open = false
    end
    @SQLFreeHandle(_ODBC.handle_stmt(), _hstmt)
    _hstmt = Pointer[None]
    _closed = true
    _col_bindings = None

  fun _final() =>
    if not _closed then
      @SQLFreeHandle(_ODBC.handle_stmt(), _hstmt)
    end
