class val SqlSmallInt
  """
  SQL SMALLINT. Wraps I16.
  """
  let value: I16

  new val create(v: I16) =>
    value = v

  fun string(): String iso^ =>
    value.string()
