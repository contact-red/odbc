"""
# ODBC

Pony wrapper for unixODBC. Provides typed, safe access to ODBC data sources
with runtime state checking, redacted error diagnostics, and immutable Row
snapshots.

## Usage

```pony
use "odbc"

actor Main
  new create(env: Env) =>
    match Odbc.connect(Dsn("DSN=mydb"))
    | let conn: Connection =>
      match conn.exec("CREATE TABLE t (id INTEGER)")
      | let e: ExecError => env.err.print(e.string())
      end
      conn.close()
    | let e: ConnectError =>
      env.err.print(e.string())
    end
```
"""

primitive Odbc
  """
  Entry point for ODBC connections.
  """

  fun connect(
    dsn: Dsn,
    opts: OdbcOptions = OdbcOptions)
    : (Connection | ConnectError)
  =>
    """
    Connect to an ODBC data source. Each Connection owns its own
    SQLHENV (no shared environment handle across connections).
    OdbcOptions carries UTF-8 validation and per-column size limits;
    see its definition for defaults.
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

    Connection._create(henv, hdbc, warnings, opts)
