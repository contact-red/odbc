class val SqlInteger
  """
  SQL INTEGER. Wraps I32.
  """
  let value: I32

  new val create(v: I32) =>
    value = v

  fun string(): String iso^ =>
    value.string()
