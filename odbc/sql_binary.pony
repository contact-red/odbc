class val SqlBinary is SqlValue
  """
  Binary data (BINARY, VARBINARY, LONGVARBINARY). Wraps the bytes
  the driver returned with no encoding interpretation. Binds zero-copy:
  ODBC reads bytes directly out of the Array's backing buffer.
  """
  let value: Array[U8] val

  new val create(v: Array[U8] val) =>
    value = v

  fun string(): String iso^ =>
    recover iso
      String
        .> append("Binary(")
        .> append(value.size().string())
        .> append(" bytes)")
    end

  fun c_data_type(): I16 => ODBCConstants.c_binary()
  fun sql_type(): I16 => ODBCConstants.sql_varbinary()
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
