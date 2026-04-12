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

  // Per-param state
  let _bound_flags: Array[Bool] ref
  let _param_bufs: Array[Array[U8]] ref
  let _param_inds: Array[I64] ref
  // Track the C type per param so we can distinguish I64 from F64
  let _param_c_types: Array[I16] ref
  var _params_bound_to_odbc: Bool  // true after first SQLBindParameter call
  var _needs_rebind: Bool          // dirty flag for text slot growth

  // Column bindings — created on first execute(), reused across fetches
  var _col_bindings: (_ColumnBindings | None)
  let _validate_utf8: Bool

  new ref _create(hstmt: Pointer[None] tag, param_count: U16,
    conn_alive: _AliveFlag ref, validate_utf8: Bool = true) =>
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
      return ExecError(StatementClosed,
        recover val Array[DiagRecord] end)
    end
    if not _conn_alive.is_alive() then
      return ExecError(ConnectionClosed,
        recover val Array[DiagRecord] end)
    end
    None

  // --- Binding ---

  fun ref bind(i: ParamIndex, v: SqlValue): (None | BindError) =>
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

      match v
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
      end

      _bound_flags(pos)? = true
    else
      return BindError(ParamIndexOutOfRange, i)
    end
    None

  fun ref bind_null(i: ParamIndex): (None | BindError) =>
    bind(i, SqlNull)

  // --- Execution ---

  fun ref execute(): (None | ExecError) =>
    """
    Execute a prepared SELECT, opening a cursor.
    """
    match _check_alive()
    | let e: ExecError => return e
    end
    if _cursor_open then
      return ExecError(CursorAlreadyOpen,
        recover val Array[DiagRecord] end)
    end

    match _check_all_bound()
    | let e: ExecError => return e
    end

    match _bind_params_to_odbc()
    | let e: ExecError => return e
    end

    let rc = @SQLExecute(_hstmt)
    _last_warnings = if _ODBC.has_info(rc) then
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
      // Column binding failed — still have a cursor, just can't fetch
      let diag = _DiagHelper.read(_ODBC.handle_stmt(), _hstmt)
      return ExecError(ExecErrorClassifier.classify(diag), diag)
    end

    _cursor_open = true
    None

  fun ref execute_update(): (RowCount | ExecError) =>
    """
    Execute a prepared DML. Returns affected row count.
    """
    match _check_alive()
    | let e: ExecError => return e
    end
    if _cursor_open then
      return ExecError(CursorAlreadyOpen,
        recover val Array[DiagRecord] end)
    end

    match _check_all_bound()
    | let e: ExecError => return e
    end

    match _bind_params_to_odbc()
    | let e: ExecError => return e
    end

    let rc = @SQLExecute(_hstmt)
    _last_warnings = if _ODBC.has_info(rc) then
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
      None
    else
      row_count.usize()
    end

  fun ref _check_all_bound(): (None | ExecError) =>
    if _param_count == 0 then return None end
    var i: USize = 0
    while i < _param_count.usize() do
      try
        if not _bound_flags(i)? then
          return ExecError(UnboundParams,
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

        let sql_type: I16 = match c_type
        | _ODBC.c_bit() => _ODBC.sql_bit()
        | _ODBC.c_sbigint() => _ODBC.sql_bigint()
        | _ODBC.c_double() => _ODBC.sql_double()
        else _ODBC.sql_varchar() // c_char or null
        end

        let col_size: U64 = if c_type == _ODBC.c_char() then
          if ind > 0 then ind.u64() else 1 end
        else
          0
        end

        let rc = @SQLBindParameter(_hstmt, param_num,
          _ODBC.sql_param_input(), c_type, sql_type,
          col_size, 0,
          buf.cpointer(), buf.size().i64(),
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

  // --- Fetching ---

  fun ref fetch(): (Row | EndOfRows | FetchError) =>
    """
    Fetch the next row. Row is a val snapshot.
    """
    if _closed then return FetchError(CursorClosed) end
    if not _conn_alive.is_alive() then return FetchError(FetchConnectionClosed) end
    if not _cursor_open then return FetchError(CursorClosed) end

    let rc = @SQLFetch(_hstmt)

    if rc == _ODBC.sql_no_data() then
      return EndOfRows
    end

    _last_warnings = if _ODBC.has_info(rc) then
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

  fun ref values(): StatementIterator =>
    """
    Return an iterator for use with Pony's `for` loop.
    FetchError during iteration raises error from next().
    """
    StatementIterator(this)

  // --- Cursor management ---

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

  // --- Observability ---

  fun ref last_warnings(): (Warnings | None) =>
    _last_warnings

  // --- Lifecycle ---

  fun ref close() =>
    """
    Free the SQLHSTMT. Idempotent.
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
