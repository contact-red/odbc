class val SqlDecimal
  """
  SQL NUMERIC/DECIMAL. Stored as string to preserve precision.
  """
  let value: String val

  new val create(v: String val) =>
    value = v

  fun string(): String iso^ =>
    value.string()
