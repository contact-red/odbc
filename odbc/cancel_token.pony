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
  for row in stmt.values() do ... end

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
    Safe to call from any actor. No-op if the statement has already
    completed or been closed.
    """
    @SQLCancel(_hstmt)
