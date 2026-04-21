class val SqlTimestamp
  """
  SQL TIMESTAMP. Date + time + fractional seconds (nanoseconds).
  """
  let year: I16
  let month: U16
  let day: U16
  let hour: U16
  let minute: U16
  let second: U16
  let fraction: U32

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
