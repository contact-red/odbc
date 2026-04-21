class val SqlTinyInt
  """
  SQL TINYINT. Wraps I8.
  """
  let value: I8

  new val create(v: I8) =>
    value = v

  fun string(): String iso^ =>
    value.string()
