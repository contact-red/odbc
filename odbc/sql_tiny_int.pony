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
  fun populate_buffer(buf: Array[U8])? =>
    if false then error end
    @memcpy(buf.cpointer(), addressof value, 1)
