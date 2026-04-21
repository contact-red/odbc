class val SqlFloat is SqlValue
  """
  Wraps F64. All float column types (REAL, DOUBLE, FLOAT) are read
  via SQL_C_DOUBLE and surfaced as F64.
  """
  var value: F64

  new val create(v: F64) =>
    value = v

  fun string(): String iso^ =>
    value.string()

  fun c_data_type(): I16 => ODBCConstants.c_double()

  fun populate_buffer(buf: Array[U8])? =>
    if false then error end
    @memcpy(buf.cpointer(), addressof value, 8)
