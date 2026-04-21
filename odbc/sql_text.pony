class val SqlText is SqlValue
  """
  Wraps String val. Validated UTF-8 at the FFI boundary.
  """
  let value: String val

  new val create(v: String val) =>
    value = v

  fun string(): String iso^ =>
    value.string()

  fun c_data_type(): I16 => ODBCConstants.c_char()
  fun required_size(): USize => value.size()
  fun len_or_indptr(): I64 => value.size().i64()

  fun populate_buffer(buf: Array[U8]) =>
    @memcpy(buf.cpointer(), value.cpointer(), value.size())
