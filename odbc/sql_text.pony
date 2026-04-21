class val SqlText
  """
  Wraps String val. Validated UTF-8 at the FFI boundary.
  """
  let value: String val

  new val create(v: String val) =>
    value = v

  fun string(): String iso^ =>
    value.string()
