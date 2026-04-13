use "promises"

actor DbSession
  """
  Actor wrapper around Connection. Provides non-blocking behaviors that
  return Promises, enabling concurrent database access without blocking
  the caller's actor.

  Each DbSession owns one Connection. Operations are serialized through
  the actor's mailbox — no concurrent access to the underlying ODBC handles.

  Usage:
  ```pony
  let db = DbSession(Dsn("DSN=mydb"))
  let p = db.exec("CREATE TABLE t (id INTEGER)")
  p.next[None]({(result: (RowCount | ExecError)) =>
    match result
    | let rc: RowCount => env.out.print("done")
    | let e: ExecError => env.err.print(e.string())
    end
  })
  ```
  """

  var _conn: (Connection | ConnectError)
  let _validate_utf8: Bool

  new create(dsn: Dsn, validate_utf8: Bool = true) =>
    _validate_utf8 = validate_utf8
    _conn = Odbc.connect(dsn, validate_utf8)

  be exec(sql: String val, promise: Promise[(RowCount | ExecError)]) =>
    """
    Execute DDL/DML and fulfill the promise with the result.
    """
    match \exhaustive\ _conn
    | let conn: Connection =>
      promise(conn.exec(sql))
    | let e: ConnectError =>
      promise(ExecError(
        ConnectionClosed, recover val Array[DiagRecord] end, sql))
    end

  be query(sql: String val,
    promise: Promise[(Array[Row val] val | ExecError)]) =>
    """
    Execute a SELECT and fulfill the promise with all rows.
    Fetches all rows into memory.
    """
    match \exhaustive\ _conn
    | let conn: Connection =>
      match \exhaustive\ conn.query(sql)
      | let cursor: Cursor =>
        let rows = recover iso Array[Row val] end
        while true do
          match \exhaustive\ cursor.fetch()
          | let row: Row => rows.push(row)
          | EndOfRows => break
          | let e: FetchError =>
            cursor.close()
            let ediag = e.unsafe_diag()
            promise(ExecError(
              ExecErrorClassifier.classify(ediag), ediag))
            return
          end
        end
        cursor.close()
        promise(consume rows)
      | let e: ExecError =>
        promise(e)
      end
    | let e: ConnectError =>
      promise(ExecError(
        ConnectionClosed, recover val Array[DiagRecord] end, sql))
    end

  be begin(promise: Promise[(TxBegun | TxBeginError)]) =>
    """
    Begin a transaction.
    """
    match \exhaustive\ _conn
    | let conn: Connection => promise(conn.begin())
    | let _: ConnectError =>
      promise(TxBeginError(TxBeginConnectionClosed))
    end

  be commit(promise: Promise[(TxCommitted | TxCommitError)]) =>
    """
    Commit the current transaction.
    """
    match \exhaustive\ _conn
    | let conn: Connection => promise(conn.commit())
    | let _: ConnectError =>
      promise(TxCommitError(NotInTransaction))
    end

  be rollback(promise: Promise[(TxRolledBack | TxRollbackError)]) =>
    """
    Rollback the current transaction.
    """
    match \exhaustive\ _conn
    | let conn: Connection => promise(conn.rollback())
    | let _: ConnectError =>
      promise(TxRollbackError(RollbackNotInTransaction))
    end

  be close() =>
    """
    Close the underlying connection.
    """
    match _conn
    | let conn: Connection => conn.close()
    end
