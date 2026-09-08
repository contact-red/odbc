class val SqlTime is SqlValue
  """
  SQL TIME. Hour (0-23), minute (0-59), second (0-59).
  """
  var hour: U16
  var minute: U16
  var second: U16
  let _buf: Array[U8] val

  new val create(hour': U16, minute': U16, second': U16) =>
    hour = hour'
    minute = minute'
    second = second'
    _buf =
      recover val
        let b = Array[U8].init(0, ODBCConstants.time_struct_size())
        @odbc_encode_time(b.cpointer(), hour', minute', second')
        b
      end

  fun string(): String iso^ =>
    recover iso
      let s = String(8)
      if hour < 10 then s.push('0') end
      s.append(hour.string())
      s.push(':')
      if minute < 10 then s.push('0') end
      s.append(minute.string())
      s.push(':')
      if second < 10 then s.push('0') end
      s.append(second.string())
      s
    end

  fun c_data_type(): I16 => ODBCConstants.c_type_time()

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
      _buf.cpointer(), _buf.size().i64(),
      ind_ptr)

primitive _SqlTimeDecode
  fun apply(buf: Pointer[U8] tag): SqlTime =>
    var hr: U16 = 0
    var mi: U16 = 0
    var se: U16 = 0
    @odbc_decode_time(buf, addressof hr, addressof mi, addressof se)
    SqlTime(hr, mi, se)
