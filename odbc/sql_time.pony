class val SqlTime is SqlValue
  """
  SQL TIME. Hour (0-23), minute (0-59), second (0-59).
  """
  var hour: U16
  var minute: U16
  var second: U16

  new val create(hour': U16, minute': U16, second': U16) =>
    hour = hour'
    minute = minute'
    second = second'

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

  fun populate_buffer(buf: Array[U8])? =>
    if false then error end
    @memcpy(buf.cpointer(),  addressof hour, 2)
    @memcpy(buf.cpointer(2), addressof minute, 2)
    @memcpy(buf.cpointer(4), addressof second, 2)
