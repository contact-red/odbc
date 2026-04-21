class val SqlBigInt
  """
  SQL BIGINT. Wraps I64.
  """
  let value: I64

  new val create(v: I64) =>
    value = v

  fun string(): String iso^ =>
    value.string()
