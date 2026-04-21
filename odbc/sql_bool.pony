class val SqlBool is SqlValue
  """
  SQL boolean value.
  """
  let value: Bool

  new val create(v: Bool) =>
    value = v

  fun string(): String iso^ =>
    value.string()

  fun c_data_type(): I16 => ODBCConstants.c_bit()
  fun required_size(): USize => 1
  fun len_or_indptr(): I64 => 1

  fun populate_buffer(buf: Array[U8]) =>
    var v: U8 = if value then 1 else 0 end
    @memcpy(buf.cpointer(), addressof v, 1)
