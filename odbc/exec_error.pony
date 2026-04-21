class val ExecError
  """
  Error executing a SQL statement.
  """
  let _kind: ExecErrorKind
  let _diag: DiagChain
  let _sql: (String val | None)

  new val create(
    kind': ExecErrorKind,
    diag': DiagChain,
    sql': (String val | None) = None) =>
    _kind = kind'
    _diag = diag'
    _sql = sql'

  fun kind(): ExecErrorKind => _kind

  fun string(): String iso^ =>
    """
    Redacted. Returns kind + SQLSTATE. No SQL text.
    """
    recover iso
      let s = String
      s.append("ExecError: ")
      s.append(_kind.string())
      try
        let rec = _diag(0)?
        s.append(" [")
        s.append(rec.sqlstate)
        s.append("]")
      end
      s
    end

  fun unsafe_sql(): (String val | None) => _sql
  fun unsafe_diag(): DiagChain => _diag

type ExecErrorKind is
  ( QueryError
  | ConstraintViolation
  | SyntaxError
  | ConnectionLost
  | UnboundParams
  | StatementClosed
  | ConnectionClosed
  | CursorNotOpen
  | CursorAlreadyOpen
  )

primitive QueryError
  """
  General driver-reported SQL error.
  """
  fun string(): String val => "query error"

primitive ConstraintViolation
  """
  Integrity constraint violation (SQLSTATE 23xxx).
  """
  fun string(): String val => "constraint violation"

primitive SyntaxError
  """
  SQL syntax error or access rule violation (SQLSTATE 42xxx).
  """
  fun string(): String val => "syntax error"

primitive ConnectionLost
  """
  Connection to the database was lost.
  """
  fun string(): String val => "connection lost"

primitive UnboundParams
  """
  Not all parameters were bound before execute.
  """
  fun string(): String val => "unbound parameters"

primitive StatementClosed
  """
  Operation attempted on a closed statement.
  """
  fun string(): String val => "statement closed"

primitive ConnectionClosed
  """
  Operation attempted on a closed connection.
  """
  fun string(): String val => "connection closed"

primitive CursorNotOpen
  """
  Fetch attempted without an open cursor.
  """
  fun string(): String val => "cursor not open"

primitive CursorAlreadyOpen
  """
  Execute attempted while a cursor is open.
  """
  fun string(): String val => "cursor already open"
