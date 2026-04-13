primitive Odbc
  """
  Entry point for ODBC connections.
  """

  fun connect(
    dsn: Dsn,
    validate_utf8: Bool = true)
    : (Connection | ConnectError)
  =>
    """
    Connect to an ODBC data source. Each Connection owns its own
    SQLHENV (no shared environment handle across connections).
    Set validate_utf8 to false to skip UTF-8 validation on text columns.
    """

    // Allocate environment handle
    var henv: Pointer[None] tag = Pointer[None]
    var rc =
      @SQLAllocHandle(
      _ODBC.handle_env(), _ODBC.null_handle(), addressof henv)
    if not _ODBC.ok(rc) then
      return ConnectError(
        EnvAllocFailed, recover val Array[DiagRecord] end)
    end

    // Set ODBC version
    rc =
      @SQLSetEnvAttr(
      henv, _ODBC.attr_odbc_version(), _ODBC.ov_odbc3(), 0)
    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_env(), henv)
      @SQLFreeHandle(_ODBC.handle_env(), henv)
      return ConnectError(EnvAllocFailed, diag)
    end

    // Allocate connection handle
    var hdbc: Pointer[None] tag = Pointer[None]
    rc =
      @SQLAllocHandle(
      _ODBC.handle_dbc(), henv, addressof hdbc)
    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_env(), henv)
      @SQLFreeHandle(_ODBC.handle_env(), henv)
      return ConnectError(DbcAllocFailed, diag)
    end

    // Connect
    let conn_str = dsn._string()
    var out_len: I16 = 0
    rc =
      @SQLDriverConnect(
      hdbc,
      _ODBC.null_handle(),
      conn_str.cpointer(),
      conn_str.size().i16(),
      _ODBC.null_handle(),
      0,
      addressof out_len,
      _ODBC.driver_noprompt())

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_dbc(), hdbc)
      @SQLFreeHandle(_ODBC.handle_dbc(), hdbc)
      @SQLFreeHandle(_ODBC.handle_env(), henv)
      return ConnectError(DriverConnectFailed, diag)
    end

    // Collect any SQL_SUCCESS_WITH_INFO warnings
    let warnings: (Warnings | None) =
      if _ODBC.has_info(rc) then
        Warnings(_DiagHelper.read(_ODBC.handle_dbc(), hdbc))
      else
        None
      end

    Connection._create(henv, hdbc, warnings, validate_utf8)

class ref Connection
  """
  Non-sendable database connection wrapping SQLHDBC (and its own SQLHENV).
  All methods check internal state and return errors for misuse.
  """

  var _henv: Pointer[None] tag
  var _hdbc: Pointer[None] tag
  var _closed: Bool
  var _in_tx: Bool
  let _alive: _AliveFlag
  var _last_warnings: (Warnings | None)
  let _validate_utf8: Bool

  new ref _create(
    henv: Pointer[None] tag,
    hdbc: Pointer[None] tag,
    warnings: (Warnings | None) = None,
    validate_utf8: Bool = true)
  =>
    _henv = henv
    _hdbc = hdbc
    _closed = false
    _in_tx = false
    _alive = _AliveFlag
    _last_warnings = warnings
    _validate_utf8 = validate_utf8

  fun ref exec(sql: String val): (RowCount | ExecError) =>
    """
    Execute a non-parameterized statement via SQLExecDirect.
    Returns affected row count, or None for DDL.
    """
    if _closed then
      return ExecError(
        ConnectionClosed, recover val Array[DiagRecord] end, sql)
    end

    // Allocate a temporary statement handle
    var hstmt: Pointer[None] tag = Pointer[None]
    var rc =
      @SQLAllocHandle(
      _ODBC.handle_stmt(), _hdbc, addressof hstmt)
    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_dbc(), _hdbc)
      return ExecError(
        ExecErrorClassifier.classify(diag), diag, sql)
    end

    rc =
      @SQLExecDirect(
      hstmt, sql.cpointer(), sql.size().i32())

    // Capture warnings before anything else
    _last_warnings =
      if _ODBC.has_info(rc) then
        Warnings(
          _DiagHelper.read(_ODBC.handle_stmt(), hstmt))
      else
        None
      end

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_stmt(), hstmt)
      @SQLFreeHandle(_ODBC.handle_stmt(), hstmt)
      return ExecError(
        ExecErrorClassifier.classify(diag), diag, sql)
    end

    // Get row count
    var row_count: I64 = 0
    @SQLRowCount(hstmt, addressof row_count)

    @SQLFreeHandle(_ODBC.handle_stmt(), hstmt)

    if row_count == _ODBC.sql_no_row_count() then
      NoRowCount
    else
      row_count.usize()
    end

  fun ref exec_p(sql: String val): RowCount ? =>
    """
    Partial variant of exec(). Raises error on failure.
    For try/else chaining of multiple statements.
    """
    match \exhaustive\ exec(sql)
    | let rc: RowCount => rc
    | let _: ExecError => error
    end

  fun ref prepare(sql: String val): (Statement | PrepareError) =>
    """
    Prepare a statement for parameter binding and repeated execution.
    """
    if _closed then
      return PrepareError(
        PrepareConnectionClosed,
        recover val Array[DiagRecord] end,
        sql)
    end

    var hstmt: Pointer[None] tag = Pointer[None]
    var rc =
      @SQLAllocHandle(
      _ODBC.handle_stmt(), _hdbc, addressof hstmt)
    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_dbc(), _hdbc)
      return PrepareError(DriverPrepareError, diag, sql)
    end

    rc =
      @SQLPrepare(
      hstmt, sql.cpointer(), sql.size().i32())

    _last_warnings =
      if _ODBC.has_info(rc) then
        Warnings(
          _DiagHelper.read(_ODBC.handle_stmt(), hstmt))
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

    Statement._create(
      hstmt, num_params.u16(), _alive, _validate_utf8)

  fun ref prepare_p(sql: String val): Statement ? =>
    """
    Partial variant of prepare(). Raises error on failure.
    """
    match \exhaustive\ prepare(sql)
    | let s: Statement => s
    | let _: PrepareError => error
    end

  fun ref query(sql: String val): (Cursor | ExecError) =>
    """
    Execute a SELECT via SQLExecDirect and return a Cursor.
    """
    if _closed then
      return ExecError(
        ConnectionClosed, recover val Array[DiagRecord] end, sql)
    end

    var hstmt: Pointer[None] tag = Pointer[None]
    var rc =
      @SQLAllocHandle(
      _ODBC.handle_stmt(), _hdbc, addressof hstmt)
    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_dbc(), _hdbc)
      return ExecError(
        ExecErrorClassifier.classify(diag), diag, sql)
    end

    rc =
      @SQLExecDirect(
      hstmt, sql.cpointer(), sql.size().i32())

    _last_warnings =
      if _ODBC.has_info(rc) then
        Warnings(
          _DiagHelper.read(_ODBC.handle_stmt(), hstmt))
      else
        None
      end

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_stmt(), hstmt)
      @SQLFreeHandle(_ODBC.handle_stmt(), hstmt)
      return ExecError(
        ExecErrorClassifier.classify(diag), diag, sql)
    end

    try
      Cursor._create(hstmt, _alive, _validate_utf8)?
    else
      // Column binding failed — close cursor and free handle
      @SQLFreeStmt(hstmt, _ODBC.sql_close_cursor())
      let diag = _DiagHelper.read(_ODBC.handle_stmt(), hstmt)
      @SQLFreeHandle(_ODBC.handle_stmt(), hstmt)
      ExecError(ExecErrorClassifier.classify(diag), diag, sql)
    end

  fun ref query_p(sql: String val): Cursor ? =>
    """
    Partial variant of query(). Raises error on failure.
    """
    match \exhaustive\ query(sql)
    | let c: Cursor => c
    | let _: ExecError => error
    end

  fun ref begin(): (TxBegun | TxBeginError) =>
    """
    Set autocommit off. Returns error if already in a transaction
    or if the connection is closed.
    """
    if _closed then
      return TxBeginError(TxBeginConnectionClosed)
    end
    if _in_tx then
      return TxBeginError(AlreadyInTransaction)
    end

    let rc =
      @SQLSetConnectAttr(
      _hdbc, _ODBC.attr_autocommit(), _ODBC.autocommit_off(), 0)

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_dbc(), _hdbc)
      return TxBeginError(DriverTxError, diag)
    end

    _last_warnings =
      if _ODBC.has_info(rc) then
        Warnings(
          _DiagHelper.read(_ODBC.handle_dbc(), _hdbc))
      else
        None
      end

    _in_tx = true
    TxBegun

  fun ref commit(): (TxCommitted | TxCommitError) =>
    """
    Commit the current transaction and re-enable autocommit.
    """
    if _closed then
      return TxCommitError(NotInTransaction)
    end
    if not _in_tx then
      return TxCommitError(NotInTransaction)
    end

    let rc =
      @SQLEndTran(
      _ODBC.handle_dbc(), _hdbc, _ODBC.sql_commit())

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_dbc(), _hdbc)
      let verdict =
        try
          let state = diag(0)?.sqlstate
          let is_08 =
            try
              (state(0)? == '0') and (state(1)? == '8')
            else
              false
            end
          if (state.size() >= 2) and is_08 then
            CommitAmbiguous
          else
            CommitFailed
          end
        else
          CommitFailed
        end

      // Re-enable autocommit on CommitFailed (server rolled back)
      if verdict is CommitFailed then
        @SQLSetConnectAttr(
          _hdbc, _ODBC.attr_autocommit(), _ODBC.autocommit_on(), 0)
        _in_tx = false
      end

      return TxCommitError(verdict, diag)
    end

    // Success — re-enable autocommit
    @SQLSetConnectAttr(
      _hdbc, _ODBC.attr_autocommit(), _ODBC.autocommit_on(), 0)
    _in_tx = false

    _last_warnings =
      if _ODBC.has_info(rc) then
        Warnings(
          _DiagHelper.read(_ODBC.handle_dbc(), _hdbc))
      else
        None
      end
    TxCommitted

  fun ref rollback(): (TxRolledBack | TxRollbackError) =>
    """
    Rollback the current transaction and re-enable autocommit.
    """
    if _closed then
      return TxRollbackError(RollbackNotInTransaction)
    end
    if not _in_tx then
      return TxRollbackError(RollbackNotInTransaction)
    end

    let rc =
      @SQLEndTran(
      _ODBC.handle_dbc(), _hdbc, _ODBC.sql_rollback())

    // Always clear tx state
    _in_tx = false
    @SQLSetConnectAttr(
      _hdbc, _ODBC.attr_autocommit(), _ODBC.autocommit_on(), 0)

    if not _ODBC.ok(rc) then
      let diag = _DiagHelper.read(_ODBC.handle_dbc(), _hdbc)
      return TxRollbackError(DriverRollbackError, diag)
    end

    _last_warnings =
      if _ODBC.has_info(rc) then
        Warnings(
          _DiagHelper.read(_ODBC.handle_dbc(), _hdbc))
      else
        None
      end
    TxRolledBack

  fun ref begin_p() ? =>
    """
    Partial variant of begin(). Raises error on failure.
    """
    match begin()
    | let _: TxBeginError => error
    end

  fun ref commit_p() ? =>
    """
    Partial variant of commit(). Raises error on failure.
    """
    match commit()
    | let _: TxCommitError => error
    end

  fun ref rollback_p() ? =>
    """
    Partial variant of rollback(). Raises error on failure.
    """
    match rollback()
    | let _: TxRollbackError => error
    end

  fun ref last_warnings(): (Warnings | None) =>
    _last_warnings

  fun ref close() =>
    """
    Close the connection. Idempotent. Auto-rollbacks if in a transaction.
    Sets shared _alive flag to false.
    """
    if _closed then return end

    if _in_tx then
      @SQLEndTran(
        _ODBC.handle_dbc(), _hdbc, _ODBC.sql_rollback())
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
    Safety net. Calls cleanup if not already closed.
    """
    if not _closed then
      if _in_tx then
        @SQLEndTran(
          _ODBC.handle_dbc(), _hdbc, _ODBC.sql_rollback())
      end
      @SQLDisconnect(_hdbc)
      @SQLFreeHandle(_ODBC.handle_dbc(), _hdbc)
      @SQLFreeHandle(_ODBC.handle_env(), _henv)
    end
