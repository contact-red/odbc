class val SqlBool
  """
  SQL boolean value.
  """
  let value: Bool

  new val create(v: Bool) =>
    value = v

  fun string(): String iso^ =>
    value.string()
