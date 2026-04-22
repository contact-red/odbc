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
        var h = hour'; var mi = minute'; var s = second'
        let b = Array[U8].init(0, ODBCConstants.time_struct_size())
        @memcpy(b.cpointer(),  addressof h,  2)
        @memcpy(b.cpointer(2), addressof mi, 2)
        @memcpy(b.cpointer(4), addressof s,  2)
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
  fun apply(buf: Array[U8] box): SqlTime =>
    var hr: U16 = 0
    var mi: U16 = 0
    var se: U16 = 0
    @memcpy(addressof hr, buf.cpointer(),  2)
    @memcpy(addressof mi, buf.cpointer(2), 2)
    @memcpy(addressof se, buf.cpointer(4), 2)
    SqlTime(hr, mi, se)
