class val SqlTimestamp is SqlValue
  """
  SQL TIMESTAMP. Date + time + fractional seconds (nanoseconds).
  """
  var year: I16
  var month: U16
  var day: U16
  var hour: U16
  var minute: U16
  var second: U16
  var fraction: U32
  let _buf: Array[U8] val

  new val create(
    year': I16,
    month': U16,
    day': U16,
    hour': U16,
    minute': U16,
    second': U16,
    fraction': U32 = 0)
  =>
    year = year'
    month = month'
    day = day'
    hour = hour'
    minute = minute'
    second = second'
    fraction = fraction'
    _buf =
      recover val
        var y = year';   var mo = month';  var d = day'
        var h = hour';   var mi = minute'; var s = second'
        var f = fraction'
        let b = Array[U8].init(0, ODBCConstants.timestamp_struct_size())
        @memcpy(b.cpointer(),    addressof y,  2)
        @memcpy(b.cpointer(2),   addressof mo, 2)
        @memcpy(b.cpointer(4),   addressof d,  2)
        @memcpy(b.cpointer(6),   addressof h,  2)
        @memcpy(b.cpointer(8),   addressof mi, 2)
        @memcpy(b.cpointer(10),  addressof s,  2)
        @memcpy(b.cpointer(12),  addressof f,  4)
        b
      end

  fun string(): String iso^ =>
    recover iso
      let s = String(26)
      s.append(year.string())
      s.push('-')
      if month < 10 then s.push('0') end
      s.append(month.string())
      s.push('-')
      if day < 10 then s.push('0') end
      s.append(day.string())
      s.push(' ')
      if hour < 10 then s.push('0') end
      s.append(hour.string())
      s.push(':')
      if minute < 10 then s.push('0') end
      s.append(minute.string())
      s.push(':')
      if second < 10 then s.push('0') end
      s.append(second.string())
      if fraction > 0 then
        s.push('.')
        s.append(fraction.string())
      end
      s
    end

  fun c_data_type(): I16 => ODBCConstants.c_type_timestamp()

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

primitive _SqlTimestampDecode
  fun apply(buf: Pointer[U8] tag): SqlTimestamp =>
    var yr: I16 = 0
    var mo: U16 = 0
    var dy: U16 = 0
    var hr: U16 = 0
    var mi: U16 = 0
    var se: U16 = 0
    var fr: U32 = 0
    @memcpy(addressof yr, buf,            2)
    @memcpy(addressof mo, buf.offset(2),  2)
    @memcpy(addressof dy, buf.offset(4),  2)
    @memcpy(addressof hr, buf.offset(6),  2)
    @memcpy(addressof mi, buf.offset(8),  2)
    @memcpy(addressof se, buf.offset(10), 2)
    @memcpy(addressof fr, buf.offset(12), 4)
    SqlTimestamp(yr, mo, dy, hr, mi, se, fr)
