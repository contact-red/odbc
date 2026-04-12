// FFI helper for byte-level memory operations
use @memcpy[Pointer[None] tag](dst: Pointer[None] tag, src: Pointer[None] tag,
  n: USize)

class ref Statement
  """
  Non-sendable prepared statement wrapping SQLHSTMT. Reusable: bind,
  execute, fetch, close_cursor, rebind, re-execute."""

  var _hstmt: Pointer[None] tag
  let _param_count: U16
  let _conn_alive: _AliveFlag ref
  var _closed: Bool
  var _cursor_open: Bool
  var _executed_once: Bool
  var _last_warnings: (Warnings | None)

  // Per-param state
  let _bound_flags: Array[Bool] ref
  let _param_bufs: Array[Array[U8]] ref  // scratch buffer per param
  let _param_inds: Array[I64] ref        // indicator per param
  var _needs_rebind: Bool

  new ref _create(hstmt: Pointer[None] tag, param_count: U16,
    conn_alive: _AliveFlag ref) =>
    _hstmt = hstmt
    _param_count = param_count
    _conn_alive = conn_alive
    _closed = false
    _cursor_open = false
    _executed_once = false
    _last_warnings = None
    _needs_rebind = true

    let n = param_count.usize()
    _bound_flags = Array[Bool].init(false, n)
    _param_bufs = Array[Array[U8]](n)
    _param_inds = Array[I64].init(0, n)
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
    Write value into parameter scratch slot. Atomic per param."""
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
      | let sv: SqlBool =>
        buf(0)? = if sv.value then 1 else 0 end
        _param_inds(pos)? = 1
      | let sv: SqlInt =>
        // Write I64 as bytes via memcpy
        var n = sv.value
        @memcpy(buf.cpointer(), addressof n, 8)
        _param_inds(pos)? = 0 // 0 means "use buffer_length" for fixed types
      | let sv: SqlFloat =>
        var n = sv.value
        @memcpy(buf.cpointer(), addressof n, 8)
        _param_inds(pos)? = 0
      | let sv: SqlText =>
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
    Execute a prepared SELECT, opening a cursor."""
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

    _cursor_open = true
    _executed_once = true
    None

  fun ref execute_update(): (RowCount | ExecError) =>
    """
    Execute a prepared DML. Returns affected row count."""
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

    _executed_once = true

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
    Call SQLBindParameter for params that need (re)binding."""
    if (not _needs_rebind) and _executed_once then return None end
    if _param_count == 0 then return None end

    var i: USize = 0
    while i < _param_count.usize() do
      try
        let buf = _param_bufs(i)?
        let ind = _param_inds(i)?
        let param_num = (i + 1).u16()

        // Determine C type from what was bound
        // ind == -1 → NULL, ind == 1 → bool, ind == 0 → numeric (I64/F64),
        // ind > 1 → text (ind is byte length)
        let c_type: I16 = if ind == _ODBC.sql_null_data() then
          _ODBC.c_char()
        elseif ind == 1 then
          _ODBC.c_bit()
        elseif ind == 0 then
          _ODBC.c_sbigint()
        else
          _ODBC.c_char()
        end

        let sql_type: I16 = if ind == _ODBC.sql_null_data() then
          _ODBC.sql_varchar()
        elseif ind == 1 then
          _ODBC.sql_bit()
        elseif ind == 0 then
          _ODBC.sql_bigint()
        else
          _ODBC.sql_varchar()
        end

        let col_size: U64 = if c_type == _ODBC.c_char() then
          if ind > 0 then ind.u64() else 1 end
        else
          0
        end

        // We need addressof the indicator for this param.
        // Can't do addressof on array element, so use cpointer offset.
        let ind_ptr = _param_inds.cpointer(i)

        let rc = @SQLBindParameter(_hstmt, param_num,
          _ODBC.sql_param_input(), c_type, sql_type,
          col_size, 0,
          buf.cpointer(), buf.size().i64(),
          ind_ptr)

        if not _ODBC.ok(rc) then
          let diag = _DiagHelper.read(_ODBC.handle_stmt(), _hstmt)
          return ExecError(ExecErrorClassifier.classify(diag), diag)
        end
      end
      i = i + 1
    end

    _needs_rebind = false
    None

  // --- Fetching ---

  fun ref fetch(): (Row | EndOfRows | FetchError) =>
    """
    Fetch the next row. Row is a val snapshot."""
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

    // TODO: replace SQLGetData with SQLBindCol for better performance
    _ReadColumns.build_row(_hstmt)

  // --- Cursor management ---

  fun ref close_cursor() =>
    """
    Close cursor, keep statement for rebinding and re-execution."""
    if _cursor_open then
      @SQLFreeStmt(_hstmt, _ODBC.sql_close_cursor())
      _cursor_open = false
    end

  // --- Observability ---

  fun ref last_warnings(): (Warnings | None) =>
    _last_warnings

  // --- Lifecycle ---

  fun ref close() =>
    """
    Free the SQLHSTMT. Idempotent."""
    if _closed then return end
    if _cursor_open then
      @SQLFreeStmt(_hstmt, _ODBC.sql_close_cursor())
      _cursor_open = false
    end
    @SQLFreeHandle(_ODBC.handle_stmt(), _hstmt)
    _hstmt = Pointer[None]
    _closed = true

  fun _final() =>
    if not _closed then
      @SQLFreeHandle(_ODBC.handle_stmt(), _hstmt)
    end
