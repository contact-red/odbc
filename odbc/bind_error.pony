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
