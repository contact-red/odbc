class ref Cursor
  """
  Non-sendable result set from an ad-hoc query (Connection.query()).
  Supports fetch and close only — no binding, no re-execution.
  close() frees the underlying SQLHSTMT entirely.
  """

  var _hstmt: Pointer[None] tag
  let _conn_alive: _AliveFlag ref
  var _closed: Bool
  var _last_warnings: (Warnings | None)
  var _col_bindings: (_ColumnBindings | None)

  new ref _create(
    hstmt: Pointer[None] tag,
    conn_alive: _AliveFlag ref,
    validate_utf8: Bool = true) ?
  =>
    _hstmt = hstmt
    _conn_alive = conn_alive
    _closed = false
    _last_warnings = None
    // Set up column bindings immediately — cursor is already open.
    // Raises error on failure so Connection.query() can report it.
    _col_bindings = _ColumnBindings(hstmt, validate_utf8)?

  fun ref fetch(): (Row | EndOfRows | FetchError) =>
    """
    Fetch the next row.
    """
    if _closed then return FetchError(CursorClosed) end
    if not _conn_alive.is_alive() then
      return FetchError(FetchConnectionClosed)
    end

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
    | let cb: _ColumnBindings => cb.build_row()
    else FetchError(DriverFetchError)
    end

  fun ref fetch_into(row: MutableRow): (MutableRow | EndOfRows | FetchError) =>
    """
    Fetch the next row into a reusable MutableRow.
    """
    if _closed then return FetchError(CursorClosed) end
    if not _conn_alive.is_alive() then
      return FetchError(FetchConnectionClosed)
    end

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

  fun cancel_token(): CancelToken =>
    """
    Return a sendable token that can cancel this cursor's
    in-progress operation from another actor.

    The token captures a raw copy of the SQLHSTMT pointer. It does not
    track whether the cursor has been closed. Calling cancel() on a
    token after close() invokes SQLCancel on a freed handle — undefined
    behavior. The caller must ensure all outstanding tokens are discarded
    before calling close().
    """
    CancelToken(_hstmt)

  fun ref values(): CursorIterator =>
    """
    Return an iterator for use with Pony's `for` loop.
    FetchError during iteration raises error from next().
    """
    CursorIterator(this)

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
    @SQLFreeHandle(_ODBC.handle_stmt(), _hstmt)
    _hstmt = Pointer[None]
    _closed = true
    _col_bindings = None

  fun _final() =>
    if not _closed then
      @SQLFreeHandle(_ODBC.handle_stmt(), _hstmt)
    end
