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
