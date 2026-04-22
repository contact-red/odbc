primitive SqlNull is SqlValue
  """
  SQL NULL value. Binds with a null buffer pointer and an indicator of
  SQL_NULL_DATA — ODBC doesn't dereference the buffer when the indicator
  says the value is NULL.
  """
  fun string(): String val => "NULL"

  fun c_data_type(): I16 => ODBCConstants.c_char()
  fun len_or_indptr(): I64 => ODBCConstants.sql_null_data()

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
      U64(1), I16(0),
      Pointer[None], I64(0),
      ind_ptr)
