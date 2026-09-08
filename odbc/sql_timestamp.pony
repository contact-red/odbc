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
        let b = Array[U8].init(0, ODBCConstants.timestamp_struct_size())
        @odbc_encode_timestamp(b.cpointer(), year', month', day',
          hour', minute', second', fraction')
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
    @odbc_decode_timestamp(buf, addressof yr, addressof mo, addressof dy,
      addressof hr, addressof mi, addressof se, addressof fr)
    SqlTimestamp(yr, mo, dy, hr, mi, se, fr)
