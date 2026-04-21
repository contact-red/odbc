class val SqlText is SqlValue
  """
  Wraps String val. Validated UTF-8 at the FFI boundary. Binds zero-copy:
  ODBC reads bytes directly out of the String's backing buffer.
  """
  let value: String val

  new val create(v: String val) =>
    value = v

  fun string(): String iso^ =>
    value.string()

  fun c_data_type(): I16 => ODBCConstants.c_char()
  fun len_or_indptr(): I64 => value.size().i64()

  fun bind_to_odbc(
    hstmt: Pointer[None] tag,
    param_num: U16,
    ind_ptr: Pointer[I64] tag)
    : I16
  =>
    let n = value.size()
    let col_size: U64 = if n > 0 then n.u64() else 1 end
    @SQLBindParameter(
      hstmt, param_num,
      ODBCConstants.sql_param_input(),
      c_data_type(), sql_type(),
      col_size, I16(0),
      value.cpointer(), n.i64(),
      ind_ptr)
