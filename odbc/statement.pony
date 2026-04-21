class ref Statement
  """
  Non-sendable prepared statement wrapping SQLHSTMT. Reusable: bind,
  execute, fetch, close_cursor, rebind, re-execute.
  """

  var _hstmt: Pointer[None] tag
  let _param_count: U16
  let _conn_alive: _AliveFlag ref
  var _closed: Bool = false
  var _cursor_open: Bool = false
  var _last_warnings: (Warnings | None) = None
  let _bound_flags: Array[Bool] ref
  let _param_bufs: Array[Array[U8]] ref
  let _param_inds: Array[I64] ref
  var _col_bindings: (_ColumnBindings | None) = None
  let _opts: OdbcOptions

  new ref _create(
    hstmt: Pointer[None] tag,
    param_count: U16,
    conn_alive: _AliveFlag ref,
    opts: OdbcOptions = OdbcOptions)
  =>
    _hstmt = hstmt
    _param_count = param_count
    _conn_alive = conn_alive
    _opts = opts

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
      return ExecError(
        StatementClosed, recover val Array[DiagRecord] end)
    end
    if not _conn_alive.is_alive() then
      return ExecError(
        ConnectionClosed, recover val Array[DiagRecord] end)
    end
    None

  fun ref parameter_types(): (Array[SqlTypeTag] val | MetadataError) =>
    """
    SQL type tag for each parameter placeholder, as reported by
    SQLDescribeParam. Available after prepare() succeeds; no binding or
    execution required.

    Some drivers (notably SQLite's ODBC driver) do not implement
    SQLDescribeParam and return MetadataError(
    DriverDoesNotSupportDescribeParam). psqlODBC supports it.
    """
    if _closed then
      return MetadataError(MetadataStatementClosed)
    end
    if not _conn_alive.is_alive() then
      return MetadataError(MetadataConnectionClosed)
    end

    let n = _param_count.usize()
    let tags = recover iso Array[SqlTypeTag](n) end

    var i: U16 = 1
    while i.usize() <= n do
      var data_type: I16 = 0
      var param_size: U64 = 0
      var decimal_digits: I16 = 0
      var nullable: I16 = 0

      let rc =
        @SQLDescribeParam(
        _hstmt,
        i,
        addressof data_type,
        addressof param_size,
        addressof decimal_digits,
        addressof nullable)

      if not ODBCConstants.ok(rc) then
        let diag = _DiagHelper.read(ODBCConstants.handle_stmt(), _hstmt)
        return MetadataError(
          DescribeParamErrorClassifier.classify(diag), diag)
      end

      tags.push(_SqlTypeTagMap(data_type))
      i = i + 1
    end

    consume tags

  fun ref column_types(): (Array[ColumnMeta] val | MetadataError) =>
    """
    Metadata for each result column (name, type tag, nullability) as
    reported by SQLDescribeCol. Available after prepare() succeeds.
    Returns an empty array for non-result statements (INSERT, UPDATE,
    DELETE, DDL).
    """
    if _closed then
      return MetadataError(MetadataStatementClosed)
    end
    if not _conn_alive.is_alive() then
      return MetadataError(MetadataConnectionClosed)
    end

    var num_cols_raw: I16 = 0
    @SQLNumResultCols(_hstmt, addressof num_cols_raw)
    let num_cols = num_cols_raw.usize()

    let metas = recover iso Array[ColumnMeta](num_cols) end

    var col: U16 = 1
    while col.usize() <= num_cols do
      match _describe_col(col)
      | let m: ColumnMeta => metas.push(m)
      | let e: MetadataError => return e
      end
      col = col + 1
    end

    consume metas

  fun ref _describe_col(col: U16): (ColumnMeta | MetadataError) =>
    """
    Read metadata for a single result column. Two-pass: start with a
    128-byte name buffer, retry with an exact-size buffer if the driver
    reports a longer name.
    """
    let initial_cap: USize = 128
    var name_buf = Array[U8].init(0, initial_cap)
    var name_len: I16 = 0
    var data_type: I16 = 0
    var col_size: U64 = 0
    var decimal_digits: I16 = 0
    var nullable: I16 = 0

    var rc =
      @SQLDescribeCol(
      _hstmt,
      col,
      name_buf.cpointer(),
      initial_cap.i16(),
      addressof name_len,
      addressof data_type,
      addressof col_size,
      addressof decimal_digits,
      addressof nullable)

    if not ODBCConstants.ok(rc) then
      let diag = _DiagHelper.read(ODBCConstants.handle_stmt(), _hstmt)
      return MetadataError(DriverMetadataError, diag)
    end

    // col_name_max includes the null terminator, so truncation happens
    // when name_len >= (initial_cap - 1). Retry once with an exact buffer.
    if name_len.usize() >= (initial_cap - 1) then
      let bigger_cap = name_len.usize() + 1
      name_buf = Array[U8].init(0, bigger_cap)
      rc =
        @SQLDescribeCol(
        _hstmt,
        col,
        name_buf.cpointer(),
        bigger_cap.i16(),
        addressof name_len,
        addressof data_type,
        addressof col_size,
        addressof decimal_digits,
        addressof nullable)
      if not ODBCConstants.ok(rc) then
        let diag = _DiagHelper.read(ODBCConstants.handle_stmt(), _hstmt)
        return MetadataError(DriverMetadataError, diag)
      end
    end

    let actual_len = name_len.usize().min(name_buf.size())
    let name_tmp = String(actual_len)
    var j: USize = 0
    while j < actual_len do
      try name_tmp.push(name_buf(j)?) end
      j = j + 1
    end
    let name: String val = name_tmp.clone()

    ColumnMeta(
      name,
      _SqlTypeTagMap(data_type),
      _NullabilityMap(nullable))

  fun ref parameter_types_p(): Array[SqlTypeTag] val ? =>
    """
    Partial variant of parameter_types(). Raises on error.
    """
    match \exhaustive\ parameter_types()
    | let a: Array[SqlTypeTag] val => a
    | let _: MetadataError => error
    end

  fun ref column_types_p(): Array[ColumnMeta] val ? =>
    """
    Partial variant of column_types(). Raises on error.
    """
    match \exhaustive\ column_types()
    | let a: Array[ColumnMeta] val => a
    | let _: MetadataError => error
    end

  fun ref bind(i: ParamIndex, v: SqlValue): (Bound | BindError) =>
    """
    Write value into parameter scratch slot. Atomic per param.
    """
    if _closed then
      return BindError(BindStatementClosed, i)
    end
    if not _conn_alive.is_alive() then
      return BindError(BindConnectionClosed, i)
    end

    let idx = i.apply()
    if (idx == 0) or (idx > _param_count) then
      return BindError(ParamIndexOutOfRange, i)
    end

    let pos = (idx - 1).usize()

    try
      let needed = v.required_size()
      let buf =
        if needed > _param_bufs(pos)?.size() then
          let new_buf = Array[U8].init(0, needed)
          _param_bufs(pos)? = new_buf
          new_buf
        else
          _param_bufs(pos)?
        end

      v.populate_buffer(buf)
      _param_inds(pos)? = v.len_or_indptr()

      let rc = v.bind_to_odbc(_hstmt, idx, buf, _param_inds.cpointer(pos))
      if not ODBCConstants.ok(rc) then
        let diag = _DiagHelper.read(ODBCConstants.handle_stmt(), _hstmt)
        return BindError(DriverRejected, i, diag)
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

    let rc = @SQLExecute(_hstmt)
    _last_warnings =
      if ODBCConstants.has_info(rc) then
        Warnings(_DiagHelper.read(ODBCConstants.handle_stmt(), _hstmt))
      else
        None
      end

    if not ODBCConstants.ok(rc) then
      let diag = _DiagHelper.read(ODBCConstants.handle_stmt(), _hstmt)
      return ExecError(ExecErrorClassifier.classify(diag), diag)
    end

    // Set up column bindings for fetching
    try
      _col_bindings = _ColumnBindings(_hstmt, _opts)?
    else
      // Column binding failed — close the driver-level cursor so the
      // statement can be reused via close_cursor() / re-execute.
      @SQLFreeStmt(_hstmt, ODBCConstants.sql_close_cursor())
      let diag = _DiagHelper.read(ODBCConstants.handle_stmt(), _hstmt)
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

    let rc = @SQLExecute(_hstmt)
    _last_warnings =
      if ODBCConstants.has_info(rc) then
        Warnings(_DiagHelper.read(ODBCConstants.handle_stmt(), _hstmt))
      else
        None
      end

    if not ODBCConstants.ok(rc) then
      let diag = _DiagHelper.read(ODBCConstants.handle_stmt(), _hstmt)
      return ExecError(ExecErrorClassifier.classify(diag), diag)
    end

    var row_count: I64 = 0
    @SQLRowCount(_hstmt, addressof row_count)
    if row_count == ODBCConstants.sql_no_row_count() then
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

    if rc == ODBCConstants.sql_no_data() then
      return EndOfRows
    end

    _last_warnings =
      if ODBCConstants.has_info(rc) then
        Warnings(_DiagHelper.read(ODBCConstants.handle_stmt(), _hstmt))
      else
        None
      end

    if not ODBCConstants.ok(rc) then
      let diag = _DiagHelper.read(ODBCConstants.handle_stmt(), _hstmt)
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

    if rc == ODBCConstants.sql_no_data() then
      return EndOfRows
    end

    _last_warnings =
      if ODBCConstants.has_info(rc) then
        Warnings(_DiagHelper.read(ODBCConstants.handle_stmt(), _hstmt))
      else
        None
      end

    if not ODBCConstants.ok(rc) then
      let diag = _DiagHelper.read(ODBCConstants.handle_stmt(), _hstmt)
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
      @SQLFreeStmt(_hstmt, ODBCConstants.sql_close_cursor())
      @SQLFreeStmt(_hstmt, ODBCConstants.sql_unbind())
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

    If the connection has already been closed, the driver freed this
    handle transitively via SQLFreeHandle(SQL_HANDLE_DBC); in that case
    we only mark ourselves closed without a second SQLFreeHandle call
    (which would be UB on a dangling handle).
    """
    if _closed then return end
    if _conn_alive.is_alive() then
      if _cursor_open then
        @SQLFreeStmt(_hstmt, ODBCConstants.sql_close_cursor())
      end
      @SQLFreeHandle(ODBCConstants.handle_stmt(), _hstmt)
    end
    _cursor_open = false
    _hstmt = Pointer[None]
    _closed = true
    _col_bindings = None

  fun _final() =>
    if (not _closed) and _conn_alive.is_alive() then
      @SQLFreeHandle(ODBCConstants.handle_stmt(), _hstmt)
    end

primitive Executed
  """
  Statement executed successfully (cursor opened for fetching).
  """

primitive Bound
  """
  Parameter value bound successfully.
  """

primitive EndOfRows
  """
  Returned by fetch() when no more rows are available.
  """
