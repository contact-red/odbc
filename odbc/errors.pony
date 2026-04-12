// --- Connect errors ---

class val ConnectError
  let _kind: ConnectErrorKind
  let _diag: DiagChain

  new val create(kind': ConnectErrorKind, diag': DiagChain) =>
    _kind = kind'
    _diag = diag'

  fun kind(): ConnectErrorKind => _kind

  fun string(): String iso^ =>
    """
    Redacted. Returns kind only — no DSN content, no raw diag messages."""
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
    Raw diagnostic chain. May contain credentials from the driver."""
    _diag

type ConnectErrorKind is (EnvAllocFailed | DbcAllocFailed | DriverConnectFailed)

primitive EnvAllocFailed
  fun string(): String val => "environment allocation failed"
primitive DbcAllocFailed
  fun string(): String val => "connection allocation failed"
primitive DriverConnectFailed
  fun string(): String val => "driver connect failed"


// --- Exec errors ---

class val ExecError
  let _kind: ExecErrorKind
  let _diag: DiagChain
  let _sql: (String val | None)

  new val create(kind': ExecErrorKind, diag': DiagChain,
    sql': (String val | None) = None) =>
    _kind = kind'
    _diag = diag'
    _sql = sql'

  fun kind(): ExecErrorKind => _kind

  fun string(): String iso^ =>
    """
    Redacted. Returns kind + SQLSTATE. No SQL text."""
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
  fun string(): String val => "query error"
primitive ConstraintViolation
  fun string(): String val => "constraint violation"
primitive SyntaxError
  fun string(): String val => "syntax error"
primitive ConnectionLost
  fun string(): String val => "connection lost"
primitive UnboundParams
  fun string(): String val => "unbound parameters"
primitive StatementClosed
  fun string(): String val => "statement closed"
primitive ConnectionClosed
  fun string(): String val => "connection closed"
primitive CursorNotOpen
  fun string(): String val => "cursor not open"
primitive CursorAlreadyOpen
  fun string(): String val => "cursor already open"


// --- Prepare errors ---

class val PrepareError
  let _kind: PrepareErrorKind
  let _diag: DiagChain
  let _sql: (String val | None)

  new val create(kind': PrepareErrorKind, diag': DiagChain,
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
  fun string(): String val => "prepare failed"
primitive PrepareConnectionClosed
  fun string(): String val => "connection closed"


// --- Bind errors ---

class val BindError
  let _kind: BindErrorKind
  let _param_index: ParamIndex
  let _diag: DiagChain

  new val create(kind': BindErrorKind, param_index': ParamIndex,
    diag': DiagChain = recover val Array[DiagRecord] end) =>
    _kind = kind'
    _param_index = param_index'
    _diag = diag'

  fun kind(): BindErrorKind => _kind
  fun param_index(): ParamIndex => _param_index

  fun string(): String iso^ =>
    recover iso
      let s = String
      s.append("BindError: ")
      s.append(_kind.string())
      s.append(" (param ")
      s.append(_param_index.apply().string())
      s.append(")")
      s
    end

  fun unsafe_diag(): DiagChain => _diag

type BindErrorKind is (ParamIndexOutOfRange | ParamTooLarge | DriverRejected)

primitive ParamIndexOutOfRange
  fun string(): String val => "index out of range"
primitive ParamTooLarge
  fun string(): String val => "parameter too large"
primitive DriverRejected
  fun string(): String val => "driver rejected"


// --- Fetch errors ---

class val FetchError
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
  fun string(): String val => "fetch failed"
primitive ColumnTooLarge
  fun string(): String val => "column too large"
primitive UnsupportedColumnType
  fun string(): String val => "unsupported column type"
primitive InvalidUtf8
  fun string(): String val => "invalid UTF-8"
primitive FetchConnectionLost
  fun string(): String val => "connection lost"
primitive FetchConnectionClosed
  fun string(): String val => "connection closed"
primitive CursorClosed
  fun string(): String val => "cursor closed"


// --- Transaction errors ---

class val TxBeginError
  let _kind: TxBeginErrorKind
  let _diag: DiagChain

  new val create(kind': TxBeginErrorKind, diag': DiagChain =
    recover val Array[DiagRecord] end) =>
    _kind = kind'
    _diag = diag'

  fun kind(): TxBeginErrorKind => _kind

  fun string(): String iso^ =>
    recover iso
      let s = String
      s.append("TxBeginError: ")
      s.append(_kind.string())
      s
    end

  fun unsafe_diag(): DiagChain => _diag

type TxBeginErrorKind is
  (AlreadyInTransaction | TxBeginConnectionClosed | DriverTxError)

primitive AlreadyInTransaction
  fun string(): String val => "already in transaction"
primitive TxBeginConnectionClosed
  fun string(): String val => "connection closed"
primitive DriverTxError
  fun string(): String val => "driver error"


class val TxCommitError
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
  fun string(): String val => "commit failed (rolled back by server)"
primitive CommitAmbiguous
  fun string(): String val => "commit result unknown (reconnect required)"
primitive NotInTransaction
  fun string(): String val => "not in transaction"


class val TxRollbackError
  let _kind: TxRollbackErrorKind
  let _diag: DiagChain

  new val create(kind': TxRollbackErrorKind, diag': DiagChain =
    recover val Array[DiagRecord] end) =>
    _kind = kind'
    _diag = diag'

  fun kind(): TxRollbackErrorKind => _kind

  fun string(): String iso^ =>
    recover iso
      let s = String
      s.append("TxRollbackError: ")
      s.append(_kind.string())
      s
    end

  fun unsafe_diag(): DiagChain => _diag

type TxRollbackErrorKind is (RollbackNotInTransaction | DriverRollbackError)

primitive RollbackNotInTransaction
  fun string(): String val => "not in transaction"
primitive DriverRollbackError
  fun string(): String val => "driver error"


// --- Warnings ---

class val Warnings
  let _diag: DiagChain

  new val create(diag': DiagChain) =>
    _diag = diag'

  fun string(): String iso^ =>
    """
    Redacted summary."""
    recover iso
      let s = String
      s.append("Warnings: ")
      s.append(_diag.size().string())
      s.append(" diagnostic record(s)")
      s
    end

  fun unsafe_diag(): DiagChain =>
    """
    Raw diagnostic chain. May contain credential-bearing text."""
    _diag


// --- Helpers ---

primitive ExecErrorClassifier
  """
  Classify ODBC errors into ExecErrorKind based on SQLSTATE class."""

  fun classify(diag: DiagChain): ExecErrorKind =>
    try
      let state = diag(0)?.sqlstate
      if state.size() >= 2 then
        let class2 = recover val
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
