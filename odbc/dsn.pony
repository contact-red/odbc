class val Dsn
  """
  Opaque wrapper for ODBC connection strings. Separates credential-bearing
  strings from general String val at the type level.
  """
  let _raw: String val

  new val create(s: String val) =>
    _raw = s

  fun _string(): String val =>
    """
    Package-private accessor for Odbc.connect().
    """
    _raw
