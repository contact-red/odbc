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
