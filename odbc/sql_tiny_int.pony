class val SqlTinyInt is SqlValue
  """
  SQL TINYINT. Wraps I8.
  """
  var value: I8

  new val create(v: I8) =>
    value = v

  fun string(): String iso^ =>
    value.string()

  fun c_data_type(): I16 => ODBCConstants.c_stinyint()
  fun required_size(): USize => 1

  fun populate_buffer(buf: Array[U8]) =>
    @memcpy(buf.cpointer(), addressof value, 1)
