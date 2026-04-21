class val MaxColumnBytes
  """
  Validated upper bound on bytes read per text/decimal column.
  Constructed once at the connection boundary; downstream code can
  trust the value is within [min(), max()].
  """
  let _n: USize

  new val create(n: USize) ? =>
    if (n < min()) or (n > max()) then error end
    _n = n

  new val _trusted(n: USize) =>
    """
    Package-private constructor for defaults known to be in range.
    """
    _n = n

  fun apply(): USize => _n

  fun tag min(): USize =>
    """
    Floor: text column buffers must hold at least a small row's worth
    of data plus a null terminator. 4 KiB matches the pre-existing
    floor in _ColumnBindings.
    """
    4096

  fun tag max(): USize =>
    """
    Ceiling: ODBC length indicators (SQLLEN) are signed 64-bit on the
    platforms we support, so no single value can exceed I64.max_value()
    bytes regardless of the driver.
    """
    I64.max_value().usize()
