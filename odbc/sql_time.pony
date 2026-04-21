class val SqlTime
  """
  SQL TIME. Hour (0-23), minute (0-59), second (0-59).
  """
  let hour: U16
  let minute: U16
  let second: U16

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
