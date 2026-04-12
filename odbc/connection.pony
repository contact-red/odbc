primitive Odbc
  """
  Entry point for ODBC connections."""

  fun connect(dsn: Dsn): (Connection | ConnectError) =>
    """
    Connect to an ODBC data source. Each Connection owns its own
    SQLHENV (no shared environment handle across connections)."""

    // Allocate environment handle
    var henv: Pointer[None] tag = Pointer[None]
    var rc = @SQLAllocHandle(_ODBC.handle_env(), _ODBC.null_handle(),
      addressof henv)
    if not _ODBC.ok(rc) then
      return ConnectError(EnvAllocFailed,
        recover val Array[DiagRecord] end)
    end

    // Set ODBC version
    rc = @SQLSetEnvAttr(henv, _ODBC.attr_odbc_version(), _ODBC.ov_odbc3(), 0)
    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_env(), henv)
      @SQLFreeHandle(_ODBC.handle_env(), henv)
      return ConnectError(EnvAllocFailed, diag)
    end

    // Allocate connection handle
    var hdbc: Pointer[None] tag = Pointer[None]
    rc = @SQLAllocHandle(_ODBC.handle_dbc(), henv, addressof hdbc)
    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_env(), henv)
      @SQLFreeHandle(_ODBC.handle_env(), henv)
      return ConnectError(DbcAllocFailed, diag)
    end

    // Connect
    let conn_str = dsn._string()
    var out_len: I16 = 0
    rc = @SQLDriverConnect(hdbc, _ODBC.null_handle(),
      conn_str.cpointer(), conn_str.size().i16(),
      _ODBC.null_handle(), 0, addressof out_len,
      _ODBC.driver_noprompt())

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_dbc(), hdbc)
      @SQLFreeHandle(_ODBC.handle_dbc(), hdbc)
      @SQLFreeHandle(_ODBC.handle_env(), henv)
      return ConnectError(DriverConnectFailed, diag)
    end

    // Collect any SQL_SUCCESS_WITH_INFO warnings
    let warnings: (Warnings | None) = if _ODBC.has_info(rc) then
      Warnings(_DiagHelper.read(_ODBC.handle_dbc(), hdbc))
    else
      None
    end

    Connection._create(henv, hdbc, warnings)


class ref Connection
  """
  Non-sendable database connection wrapping SQLHDBC (and its own SQLHENV).
  All methods check internal state and return errors for misuse."""

  var _henv: Pointer[None] tag
  var _hdbc: Pointer[None] tag
  var _closed: Bool
  var _in_tx: Bool
  let _alive: _AliveFlag
  var _last_warnings: (Warnings | None)

  new ref _create(henv: Pointer[None] tag, hdbc: Pointer[None] tag,
    warnings: (Warnings | None) = None) =>
    _henv = henv
    _hdbc = hdbc
    _closed = false
    _in_tx = false
    _alive = _AliveFlag
    _last_warnings = warnings

  // --- DDL/DML ---

  fun ref exec(sql: String val): (RowCount | ExecError) =>
    """
    Execute a non-parameterized statement via SQLExecDirect.
    Returns affected row count, or None for DDL."""
    if _closed then
      return ExecError(ConnectionClosed,
        recover val Array[DiagRecord] end, sql)
    end

    // Allocate a temporary statement handle
    var hstmt: Pointer[None] tag = Pointer[None]
    var rc = @SQLAllocHandle(_ODBC.handle_stmt(), _hdbc, addressof hstmt)
    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_dbc(), _hdbc)
      return ExecError(ExecErrorClassifier.classify(diag), diag, sql)
    end

    rc = @SQLExecDirect(hstmt, sql.cpointer(), sql.size().i32())

    // Capture warnings before anything else
    _last_warnings = if _ODBC.has_info(rc) then
      Warnings(_DiagHelper.read(_ODBC.handle_stmt(), hstmt))
    else
      None
    end

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_stmt(), hstmt)
      @SQLFreeHandle(_ODBC.handle_stmt(), hstmt)
      return ExecError(ExecErrorClassifier.classify(diag), diag, sql)
    end

    // Get row count
    var row_count: I64 = 0
    @SQLRowCount(hstmt, addressof row_count)

    @SQLFreeHandle(_ODBC.handle_stmt(), hstmt)

    if row_count == _ODBC.sql_no_row_count() then
      None
    else
      row_count.usize()
    end

  // --- Prepared statements ---

  fun ref prepare(sql: String val): (Statement | PrepareError) =>
    """
    Prepare a statement for parameter binding and repeated execution."""
    if _closed then
      return PrepareError(PrepareConnectionClosed,
        recover val Array[DiagRecord] end, sql)
    end

    var hstmt: Pointer[None] tag = Pointer[None]
    var rc = @SQLAllocHandle(_ODBC.handle_stmt(), _hdbc, addressof hstmt)
    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_dbc(), _hdbc)
      return PrepareError(DriverPrepareError, diag, sql)
    end

    rc = @SQLPrepare(hstmt, sql.cpointer(), sql.size().i32())

    _last_warnings = if _ODBC.has_info(rc) then
      Warnings(_DiagHelper.read(_ODBC.handle_stmt(), hstmt))
    else
      None
    end

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_stmt(), hstmt)
      @SQLFreeHandle(_ODBC.handle_stmt(), hstmt)
      return PrepareError(DriverPrepareError, diag, sql)
    end

    // Get parameter count
    var num_params: I16 = 0
    @SQLNumParams(hstmt, addressof num_params)

    Statement._create(hstmt, num_params.u16(), _alive)

  // --- Ad-hoc SELECT ---

  fun ref query(sql: String val): (Cursor | ExecError) =>
    """
    Execute a SELECT via SQLExecDirect and return a Cursor."""
    if _closed then
      return ExecError(ConnectionClosed,
        recover val Array[DiagRecord] end, sql)
    end

    var hstmt: Pointer[None] tag = Pointer[None]
    var rc = @SQLAllocHandle(_ODBC.handle_stmt(), _hdbc, addressof hstmt)
    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_dbc(), _hdbc)
      return ExecError(ExecErrorClassifier.classify(diag), diag, sql)
    end

    rc = @SQLExecDirect(hstmt, sql.cpointer(), sql.size().i32())

    _last_warnings = if _ODBC.has_info(rc) then
      Warnings(_DiagHelper.read(_ODBC.handle_stmt(), hstmt))
    else
      None
    end

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_stmt(), hstmt)
      @SQLFreeHandle(_ODBC.handle_stmt(), hstmt)
      return ExecError(ExecErrorClassifier.classify(diag), diag, sql)
    end

    Cursor._create(hstmt, _alive)

  // --- Transactions ---

  fun ref begin(): (None | TxBeginError) =>
    """
    Set autocommit off. Returns error if already in a transaction
    or if the connection is closed."""
    if _closed then
      return TxBeginError(TxBeginConnectionClosed)
    end
    if _in_tx then
      return TxBeginError(AlreadyInTransaction)
    end

    let rc = @SQLSetConnectAttr(_hdbc,
      _ODBC.attr_autocommit(), _ODBC.autocommit_off(), 0)

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_dbc(), _hdbc)
      return TxBeginError(DriverTxError, diag)
    end

    _last_warnings = if _ODBC.has_info(rc) then
      Warnings(_DiagHelper.read(_ODBC.handle_dbc(), _hdbc))
    else
      None
    end

    _in_tx = true
    None

  fun ref commit(): (None | TxCommitError) =>
    """
    Commit the current transaction and re-enable autocommit."""
    if _closed then
      return TxCommitError(NotInTransaction)
    end
    if not _in_tx then
      return TxCommitError(NotInTransaction)
    end

    let rc = @SQLEndTran(_ODBC.handle_dbc(), _hdbc, _ODBC.sql_commit())

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_dbc(), _hdbc)
      let verdict = try
        let state = diag(0)?.sqlstate
        if (state.size() >= 2) and
          (try (state(0)? == '0') and (state(1)? == '8') else false end)
        then
          CommitAmbiguous
        else
          CommitFailed
        end
      else
        CommitFailed
      end

      // Re-enable autocommit on CommitFailed (server rolled back)
      if verdict is CommitFailed then
        @SQLSetConnectAttr(_hdbc,
          _ODBC.attr_autocommit(), _ODBC.autocommit_on(), 0)
        _in_tx = false
      end

      return TxCommitError(verdict, diag)
    end

    // Success — re-enable autocommit
    @SQLSetConnectAttr(_hdbc,
      _ODBC.attr_autocommit(), _ODBC.autocommit_on(), 0)
    _in_tx = false

    _last_warnings = if _ODBC.has_info(rc) then
      Warnings(_DiagHelper.read(_ODBC.handle_dbc(), _hdbc))
    else
      None
    end
    None

  fun ref rollback(): (None | TxRollbackError) =>
    """
    Rollback the current transaction and re-enable autocommit."""
    if _closed then
      return TxRollbackError(RollbackNotInTransaction)
    end
    if not _in_tx then
      return TxRollbackError(RollbackNotInTransaction)
    end

    let rc = @SQLEndTran(_ODBC.handle_dbc(), _hdbc, _ODBC.sql_rollback())

    // Always clear tx state
    _in_tx = false
    @SQLSetConnectAttr(_hdbc,
      _ODBC.attr_autocommit(), _ODBC.autocommit_on(), 0)

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_dbc(), _hdbc)
      return TxRollbackError(DriverRollbackError, diag)
    end

    _last_warnings = if _ODBC.has_info(rc) then
      Warnings(_DiagHelper.read(_ODBC.handle_dbc(), _hdbc))
    else
      None
    end
    None

  // --- Observability ---

  fun ref last_warnings(): (Warnings | None) =>
    _last_warnings

  // --- Lifecycle ---

  fun ref close() =>
    """
    Close the connection. Idempotent. Auto-rollbacks if in a transaction.
    Sets shared _alive flag to false."""
    if _closed then return end

    if _in_tx then
      @SQLEndTran(_ODBC.handle_dbc(), _hdbc, _ODBC.sql_rollback())
      _in_tx = false
    end

    _alive.set_dead()
    @SQLDisconnect(_hdbc)
    @SQLFreeHandle(_ODBC.handle_dbc(), _hdbc)
    @SQLFreeHandle(_ODBC.handle_env(), _henv)
    _hdbc = Pointer[None]
    _henv = Pointer[None]
    _closed = true

  fun _final() =>
    """
    Safety net. Calls cleanup if not already closed."""
    if not _closed then
      if _in_tx then
        @SQLEndTran(_ODBC.handle_dbc(), _hdbc, _ODBC.sql_rollback())
      end
      // Can't call _alive.set_dead() here (_final is box context).
      // Children holding _conn_alive will detect the freed handle via
      // their own null-handle checks if they outlive the Connection,
      // but ORCA's ref path ensures they finalize first.
      @SQLDisconnect(_hdbc)
      @SQLFreeHandle(_ODBC.handle_dbc(), _hdbc)
      @SQLFreeHandle(_ODBC.handle_env(), _henv)
    end
