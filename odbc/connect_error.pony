class val ConnectError
  """
  Error connecting to an ODBC data source.
  """
  let _kind: ConnectErrorKind
  let _diag: DiagChain

  new val create(kind': ConnectErrorKind, diag': DiagChain) =>
    _kind = kind'
    _diag = diag'

  fun kind(): ConnectErrorKind => _kind

  fun string(): String iso^ =>
    """
    Redacted. Returns kind only — no DSN content, no raw diag messages.
    """
    recover iso
      let s = String
      s.append("ConnectError: ")
      s.append(_kind.string())
      // Include SQLSTATE if available, but NOT the message
      try
        let rec = _diag(0)?
        s.append(" [")
        s.append(rec.sqlstate)
        s.append("]")
      end
      s
    end

  fun unsafe_diag(): DiagChain =>
    """
    Raw diagnostic chain. May contain credentials from the driver.
    """
    _diag

type ConnectErrorKind is (EnvAllocFailed | DbcAllocFailed | DriverConnectFailed)

primitive EnvAllocFailed
  """
  ODBC environment handle allocation failed.
  """
  fun string(): String val => "environment allocation failed"

primitive DbcAllocFailed
  """
  ODBC connection handle allocation failed.
  """
  fun string(): String val => "connection allocation failed"

primitive DriverConnectFailed
  """
  ODBC driver connect call failed.
  """
  fun string(): String val => "driver connect failed"


