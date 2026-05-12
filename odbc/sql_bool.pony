class val SqlBool is SqlValue
  """
  SQL boolean value. `value` is the public Bool; `_byte` is the 1-byte
  form whose address we hand to SQLBindParameter (Pony's Bool layout
  isn't a documented 1-byte guarantee, so we keep an explicit U8).
  """
  let value: Bool
  var _byte: U8

  new val create(v: Bool) =>
    value = v
    _byte = if v then 1 else 0 end

  fun string(): String iso^ =>
    value.string()

  fun c_data_type(): I16 => ODBCConstants.c_bit()

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
      addressof _byte, I64(1),
      ind_ptr)

primitive _SqlBoolDecode
  fun apply(buf: Pointer[U8] tag): SqlBool =>
    var v: U8 = 0
    @memcpy(addressof v, buf, 1)
    SqlBool(v != 0)
