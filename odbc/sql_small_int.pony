class val SqlSmallInt is SqlValue
  """
  SQL SMALLINT. Wraps I16.
  """
  var value: I16

  new val create(v: I16) =>
    value = v

  fun string(): String iso^ =>
    value.string()

  fun c_data_type(): I16 => ODBCConstants.c_sshort()

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
      addressof value, I64(2),
      ind_ptr)

primitive _SqlSmallIntDecode
  fun apply(buf: Pointer[U8] tag): SqlSmallInt =>
    var v: I16 = 0
    @memcpy(addressof v, buf, 2)
    SqlSmallInt(v)
