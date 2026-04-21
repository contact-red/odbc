class val SqlBool is SqlValue
  """
  SQL boolean value.
  """
  let value: Bool

  new val create(v: Bool) =>
    value = v

  fun string(): String iso^ =>
    value.string()

  fun len_or_indptr(): I64 => 1
  fun c_data_type(): I16 => ODBCConstants.c_bit()
  fun populate_buffer(a: Array[U8])? => a(0)? = if value then 1 else 0 end
