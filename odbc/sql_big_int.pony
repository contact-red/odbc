class val SqlBigInt is SqlValue
  """
  SQL BIGINT. Wraps I64.
  """
  var value: I64

  new val create(v: I64) =>
    value = v

  fun string(): String iso^ =>
    value.string()

  fun c_data_type(): I16 => ODBCConstants.c_sbigint()
  fun required_size(): USize => 8

  fun populate_buffer(buf: Array[U8]) =>
    @memcpy(buf.cpointer(), addressof value, 8)
