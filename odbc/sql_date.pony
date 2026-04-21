class val SqlDate
  """
  SQL DATE. Year, month (1-12), day (1-31).
  """
  let year: I16
  let month: U16
  let day: U16

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
