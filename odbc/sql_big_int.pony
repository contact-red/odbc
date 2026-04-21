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

  fun bind_to_odbc(
    hstmt: Pointer[None] tag,
    param_num: U16,
    ind_ptr: Pointer[I64] tag)
    : I16
  =>
    @SQLBindParameter(
      hstmt, param_num,
      ODBCConstants.sql_param_input(),
      c_data_type(), sql_type(),
      U64(0), I16(0),
      addressof value, I64(8),
      ind_ptr)
