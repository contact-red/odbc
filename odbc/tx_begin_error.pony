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
