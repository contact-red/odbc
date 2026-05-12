class val SqlDate is SqlValue
  """
  SQL DATE. Year, month (1-12), day (1-31).
  """
  var year: I16
  var month: U16
  var day: U16
  let _buf: Array[U8] val

  new val create(year': I16, month': U16, day': U16) =>
    year = year'
    month = month'
    day = day'
    _buf =
      recover val
        var y = year'; var m = month'; var d = day'
        let b = Array[U8].init(0, ODBCConstants.date_struct_size())
        @memcpy(b.cpointer(),  addressof y, 2)
        @memcpy(b.cpointer(2), addressof m, 2)
        @memcpy(b.cpointer(4), addressof d, 2)
        b
      end

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

primitive _SqlDateDecode
  fun apply(buf: Pointer[U8] tag): SqlDate =>
    var yr: I16 = 0
    var mo: U16 = 0
    var dy: U16 = 0
    @memcpy(addressof yr, buf,           2)
    @memcpy(addressof mo, buf.offset(2), 2)
    @memcpy(addressof dy, buf.offset(4), 2)
    SqlDate(yr, mo, dy)
