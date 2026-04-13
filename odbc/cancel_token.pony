class val CancelToken
  """
  Sendable cancellation token. Can be sent to another actor and used
  to cancel a long-running ODBC operation via SQLCancel.

  Usage:
  ```pony
  // In the querying actor:
  let stmt = conn.prepare_p("SELECT ... complex query ...")?
  let token = stmt.cancel_token()
  supervisor.register_cancel(token)
  stmt.execute_p()?
  for result in stmt.values() do ... end

  // In the supervising actor:
  be timeout(token: CancelToken) =>
    token.cancel()
  ```

  SQLCancel is thread-safe — it can be called from any thread while
  another thread is blocked on SQLFetch/SQLExecute. The blocked call
  will return SQL_ERROR with SQLSTATE HY008 (operation canceled).
  """

  let _hstmt: Pointer[None] tag

  new val create(hstmt: Pointer[None] tag) =>
    _hstmt = hstmt

  fun cancel() =>
    """
    Request cancellation of the in-progress operation on this statement.
    Safe to call from any actor while the operation is in progress.

    WARNING: The token holds a raw copy of the SQLHSTMT pointer. If the
    owning Statement or Cursor has been closed (freeing the handle), this
    calls SQLCancel on a freed handle — undefined behavior. Callers must
    ensure the token is not used after close(). See Statement.cancel_token()
    and Cursor.cancel_token() for the lifetime contract.
    """
    @SQLCancel(_hstmt)
