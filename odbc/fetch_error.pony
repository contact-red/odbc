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
