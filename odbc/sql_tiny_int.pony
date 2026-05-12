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
      addressof value, I64(1),
      ind_ptr)

primitive _SqlTinyIntDecode
  fun apply(buf: Pointer[U8] tag): SqlTinyInt =>
    var v: I8 = 0
    @memcpy(addressof v, buf, 1)
    SqlTinyInt(v)
