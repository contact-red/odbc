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
