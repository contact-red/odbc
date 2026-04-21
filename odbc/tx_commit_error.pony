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
