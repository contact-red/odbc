class val PrepareError
  """
  Error preparing a SQL statement.
  """
  let _kind: PrepareErrorKind
  let _diag: DiagChain
  let _sql: (String val | None)

  new val create(
    kind': PrepareErrorKind,
    diag': DiagChain,
    sql': (String val | None) = None) =>
    _kind = kind'
    _diag = diag'
    _sql = sql'

  fun kind(): PrepareErrorKind => _kind

  fun string(): String iso^ =>
    recover iso
      let s = String
      s.append("PrepareError: ")
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

type PrepareErrorKind is (DriverPrepareError | PrepareConnectionClosed)

primitive DriverPrepareError
  """
  ODBC driver rejected the prepare call.
  """
  fun string(): String val => "prepare failed"

primitive PrepareConnectionClosed
  """
  Prepare attempted on a closed connection.
  """
  fun string(): String val => "connection closed"
