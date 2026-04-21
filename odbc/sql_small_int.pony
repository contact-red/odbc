class val SqlSmallInt is SqlValue
  """
  SQL SMALLINT. Wraps I16.
  """
  var value: I16

  new val create(v: I16) =>
    value = v

  fun string(): String iso^ =>
    value.string()

  fun c_data_type(): I16 => ODBCConstants.c_sshort()
  fun required_size(): USize => 2

  fun populate_buffer(buf: Array[U8]) =>
    @memcpy(buf.cpointer(), addressof value, 2)
