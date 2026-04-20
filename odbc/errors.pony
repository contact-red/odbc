

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

class val BindError
  """
  Error binding a parameter value.
  """
  let _kind: BindErrorKind
  let _param_index: ParamIndex
  let _diag: DiagChain

  new val create(
    kind': BindErrorKind,
    param_index': ParamIndex,
    diag': DiagChain = recover val Array[DiagRecord] end) =>
    _kind = kind'
    _param_index = param_index'
    _diag = diag'

  fun kind(): BindErrorKind => _kind
  fun param_index(): ParamIndex => _param_index

  fun string(): String iso^ =>
    recover iso
      String
        .> append("BindError: ")
        .> append(_kind.string())
        .> append(" (param ")
        .> append(_param_index.apply().string())
        .> append(")")
    end

  fun unsafe_diag(): DiagChain => _diag

type BindErrorKind is
  ( ParamIndexOutOfRange
  | ParamTooLarge
  | DriverRejected
  | BindStatementClosed
  | BindConnectionClosed
  )

primitive ParamIndexOutOfRange
  """
  Parameter index is zero or exceeds param count.
  """
  fun string(): String val => "index out of range"

primitive ParamTooLarge
  """
  Parameter value exceeds maximum size.
  """
  fun string(): String val => "parameter too large"

primitive DriverRejected
  """
  ODBC driver rejected the bind call.
  """
  fun string(): String val => "driver rejected"

primitive BindStatementClosed
  """
  Bind attempted on a closed statement.
  """
  fun string(): String val => "statement closed"

primitive BindConnectionClosed
  """
  Bind attempted after connection closed.
  """
  fun string(): String val => "connection closed"

class val FetchError
  """
  Error fetching a row from a result set.
  """
  let _kind: FetchErrorKind
  let _diag: DiagChain

  new val create(kind': FetchErrorKind, diag': DiagChain =
    recover val Array[DiagRecord] end) =>
    _kind = kind'
    _diag = diag'

  fun kind(): FetchErrorKind => _kind

  fun string(): String iso^ =>
    recover iso
      let s = String
      s.append("FetchError: ")
      s.append(_kind.string())
      try
        let rec = _diag(0)?
        s.append(" [")
        s.append(rec.sqlstate)
        s.append("]")
      end
      s
    end

  fun unsafe_diag(): DiagChain => _diag

type FetchErrorKind is
  ( DriverFetchError
  | ColumnTooLarge
  | UnsupportedColumnType
  | InvalidUtf8
  | FetchConnectionLost
  | FetchConnectionClosed
  | CursorClosed
  )

primitive DriverFetchError
  """
  General driver-reported fetch failure.
  """
  fun string(): String val => "fetch failed"

primitive ColumnTooLarge
  """
  Column data exceeds maximum size.
  """
  fun string(): String val => "column too large"

primitive UnsupportedColumnType
  """
  Column SQL type has no SqlValue mapping.
  """
  fun string(): String val => "unsupported column type"

primitive InvalidUtf8
  """
  Text column data failed UTF-8 validation.
  """
  fun string(): String val => "invalid UTF-8"

primitive FetchConnectionLost
  """
  Connection lost during fetch.
  """
  fun string(): String val => "connection lost"

primitive FetchConnectionClosed
  """
  Fetch attempted after connection closed.
  """
  fun string(): String val => "connection closed"

primitive CursorClosed
  """
  Fetch attempted on a closed cursor.
  """
  fun string(): String val => "cursor closed"

class val TxBeginError
  """
  Error beginning a transaction.
  """
  let _kind: TxBeginErrorKind
  let _diag: DiagChain

  new val create(kind': TxBeginErrorKind, diag': DiagChain =
    recover val Array[DiagRecord] end) =>
    _kind = kind'
    _diag = diag'

  fun kind(): TxBeginErrorKind => _kind

  fun string(): String iso^ =>
    recover iso
      String
        .> append("TxBeginError: ")
        .> append(_kind.string())
    end

  fun unsafe_diag(): DiagChain => _diag

type TxBeginErrorKind is
  (AlreadyInTransaction | TxBeginConnectionClosed | DriverTxError)

primitive AlreadyInTransaction
  """
  Begin called while already in a transaction.
  """
  fun string(): String val => "already in transaction"

primitive TxBeginConnectionClosed
  """
  Begin attempted on a closed connection.
  """
  fun string(): String val => "connection closed"

primitive DriverTxError
  """
  ODBC driver rejected the transaction operation.
  """
  fun string(): String val => "driver error"

class val TxCommitError
  """
  Error committing a transaction.
  """
  let _verdict: TxCommitVerdict
  let _diag: DiagChain

  new val create(verdict': TxCommitVerdict, diag': DiagChain =
    recover val Array[DiagRecord] end) =>
    _verdict = verdict'
    _diag = diag'

  fun verdict(): TxCommitVerdict => _verdict

  fun string(): String iso^ =>
    recover iso
      let s = String
      s.append("TxCommitError: ")
      s.append(_verdict.string())
      try
        let rec = _diag(0)?
        s.append(" [")
        s.append(rec.sqlstate)
        s.append("]")
      end
      s
    end

  fun unsafe_diag(): DiagChain => _diag

type TxCommitVerdict is (CommitFailed | CommitAmbiguous | NotInTransaction)

primitive CommitFailed
  """
  Server rejected the commit; transaction rolled back.
  """
  fun string(): String val => "commit failed (rolled back by server)"

primitive CommitAmbiguous
  """
  Commit outcome unknown; reconnect required.
  """
  fun string(): String val => "commit result unknown (reconnect required)"

primitive NotInTransaction
  """
  Commit or rollback called without an active transaction.
  """
  fun string(): String val => "not in transaction"

class val TxRollbackError
  """
  Error rolling back a transaction.
  """
  let _kind: TxRollbackErrorKind
  let _diag: DiagChain

  new val create(kind': TxRollbackErrorKind, diag': DiagChain =
    recover val Array[DiagRecord] end) =>
    _kind = kind'
    _diag = diag'

  fun kind(): TxRollbackErrorKind => _kind

  fun string(): String iso^ =>
    recover iso
      String
        .> append("TxRollbackError: ")
        .> append(_kind.string())
    end

  fun unsafe_diag(): DiagChain => _diag

type TxRollbackErrorKind is (RollbackNotInTransaction | DriverRollbackError)

primitive RollbackNotInTransaction
  """
  Rollback called without an active transaction.
  """
  fun string(): String val => "not in transaction"

primitive DriverRollbackError
  """
  ODBC driver reported an error during rollback.
  """
  fun string(): String val => "driver error"

class val Warnings
  """
  Diagnostic records from SQL_SUCCESS_WITH_INFO.
  """
  let _diag: DiagChain

  new val create(diag': DiagChain) =>
    _diag = diag'

  fun string(): String iso^ =>
    """
    Redacted summary.
    """
    recover iso
      String
        .> append("Warnings: ")
        .> append(_diag.size().string())
        .> append(" diagnostic record(s)")
    end

  fun unsafe_diag(): DiagChain =>
    """
    Raw diagnostic chain. May contain credential-bearing text.
    """
    _diag

class val MetadataError
  """
  Error reading prepare-time metadata (parameter or column descriptions).
  """
  let _kind: MetadataErrorKind
  let _diag: DiagChain

  new val create(kind': MetadataErrorKind, diag': DiagChain =
    recover val Array[DiagRecord] end) =>
    _kind = kind'
    _diag = diag'

  fun kind(): MetadataErrorKind => _kind

  fun string(): String iso^ =>
    recover iso
      let s = String
      s.append("MetadataError: ")
      s.append(_kind.string())
      try
        let rec = _diag(0)?
        s.append(" [")
        s.append(rec.sqlstate)
        s.append("]")
      end
      s
    end

  fun unsafe_diag(): DiagChain => _diag

type MetadataErrorKind is
  ( MetadataStatementClosed
  | MetadataConnectionClosed
  | DriverDoesNotSupportDescribeParam
  | DriverMetadataError
  )

primitive MetadataStatementClosed
  """
  Metadata read attempted on a closed statement.
  """
  fun string(): String val => "statement closed"

primitive MetadataConnectionClosed
  """
  Metadata read attempted after connection closed.
  """
  fun string(): String val => "connection closed"

primitive DriverDoesNotSupportDescribeParam
  """
  The ODBC driver does not implement SQLDescribeParam. Classified from
  SQLSTATE IM001 ("driver does not support this function") or HYC00
  ("optional feature not implemented"). SQLite's ODBC driver is the
  most common offender; psqlODBC supports SQLDescribeParam.
  """
  fun string(): String val => "driver does not support SQLDescribeParam"

primitive DriverMetadataError
  """
  The driver rejected SQLDescribeCol or SQLDescribeParam for a reason
  other than "not implemented" — e.g. invalid statement state.
  """
  fun string(): String val => "driver metadata error"

primitive DescribeParamErrorClassifier
  """
  Classify SQLDescribeParam failures. IM001 and HYC00 indicate the
  driver does not support the call; anything else is a generic driver
  metadata error.
  """
  fun classify(diag: DiagChain): MetadataErrorKind =>
    try
      let state = diag(0)?.sqlstate
      if (state == "IM001") or (state == "HYC00") then
        return DriverDoesNotSupportDescribeParam
      end
    end
    DriverMetadataError

primitive ExecErrorClassifier
  """
  Classify ODBC errors into ExecErrorKind based on SQLSTATE class.
  """

  fun classify(diag: DiagChain): ExecErrorKind =>
    try
      let state = diag(0)?.sqlstate
      if state.size() >= 2 then
        let class2 =
          recover val
          let s = String(2)
          try s.push(state(0)?); s.push(state(1)?) end
          s
        end
        // SQLSTATE classes:
        // 08 = connection exception
        // 23 = integrity constraint violation
        // 42 = syntax error or access rule violation
        if class2 == "08" then return ConnectionLost end
        if class2 == "23" then return ConstraintViolation end
        if class2 == "42" then return SyntaxError end
      end
    end
    QueryError
