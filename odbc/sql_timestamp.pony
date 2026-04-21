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
  fun required_size(): USize => ODBCConstants.timestamp_struct_size()

  fun populate_buffer(buf: Array[U8]) =>
    @memcpy(buf.cpointer(),   addressof year,     2)
    @memcpy(buf.cpointer(2),  addressof month,    2)
    @memcpy(buf.cpointer(4),  addressof day,      2)
    @memcpy(buf.cpointer(6),  addressof hour,     2)
    @memcpy(buf.cpointer(8),  addressof minute,   2)
    @memcpy(buf.cpointer(10), addressof second,   2)
    @memcpy(buf.cpointer(12), addressof fraction, 4)
