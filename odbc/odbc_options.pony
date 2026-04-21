class val OdbcOptions
  """
  Tuning knobs applied once at connect() and propagated to every
  statement and cursor created from the connection.
  """
  let validate_utf8: Bool
  let max_column_bytes: MaxColumnBytes

  new val create(
    validate_utf8': Bool = true,
    max_column_bytes': MaxColumnBytes = MaxColumnBytes._trusted(16_777_216))
  =>
    validate_utf8 = validate_utf8'
    max_column_bytes = max_column_bytes'
