class val SqlDate is SqlValue
  """
  SQL DATE. Year, month (1-12), day (1-31).
  """
  var year: I16
  var month: U16
  var day: U16

  new val create(year': I16, month': U16, day': U16) =>
    year = year'
    month = month'
    day = day'

  fun string(): String iso^ =>
    recover iso
      let s = String(10)
      s.append(year.string())
      s.push('-')
      if month < 10 then s.push('0') end
      s.append(month.string())
      s.push('-')
      if day < 10 then s.push('0') end
      s.append(day.string())
      s
    end

  fun c_data_type(): I16 => ODBCConstants.c_type_date()
  fun required_size(): USize => ODBCConstants.date_struct_size()

  fun populate_buffer(buf: Array[U8]) =>
    @memcpy(buf.cpointer(),  addressof year, 2)
    @memcpy(buf.cpointer(2), addressof month, 2)
    @memcpy(buf.cpointer(4), addressof day, 2)
