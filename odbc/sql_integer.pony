class val SqlInteger is SqlValue
  """
  SQL INTEGER. Wraps I32.
  """
  var value: I32

  new val create(v: I32) =>
    value = v

  fun string(): String iso^ =>
    value.string()

  fun c_data_type(): I16 => ODBCConstants.c_slong()
  fun required_size(): USize => 4

  fun populate_buffer(buf: Array[U8]) =>
    @memcpy(buf.cpointer(), addressof value, 4)
