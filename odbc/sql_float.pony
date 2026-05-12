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

primitive _SqlFloatDecode
  fun apply(buf: Pointer[U8] tag): SqlFloat =>
    var v: F64 = 0
    @memcpy(addressof v, buf, 8)
    SqlFloat(v)
