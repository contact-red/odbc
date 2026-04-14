class val Dsn
  """
  Opaque wrapper for ODBC connection strings. Separates credential-bearing
  strings from general String val at the type level.
  """
  let _raw: String val

  new val create(s: String val) =>
    _raw = s

  fun _string(): String val =>
    """
    Package-private accessor for Odbc.connect().
    """
    _raw

class val ParamIndex
  """
  1-based parameter index. Bounds checking happens at bind time.
  """
  let _n: U16

  new val create(n: U16) =>
    _n = n

  fun apply(): U16 => _n

  fun string(): String iso^ =>
    _n.string()

class val ColIndex
  """
  1-based column index. Bounds checking happens at row access time.
  """
  let _n: U16

  new val create(n: U16) =>
    _n = n

  fun apply(): U16 => _n

  fun string(): String iso^ =>
    _n.string()

type RowCount is (USize | NoRowCount)
  """
  Result of exec/execute_update. USize is affected row count.
  NoRowCount means the driver returned SQL_NO_ROW_COUNT (-1).
  """

primitive NoRowCount
  """
  The driver did not report an affected row count.
  """

primitive Executed
  """
  Statement executed successfully (cursor opened for fetching).
  """

primitive Bound
  """
  Parameter value bound successfully.
  """

primitive TxBegun
  """
  Transaction started successfully.
  """

primitive TxCommitted
  """
  Transaction committed successfully.
  """

primitive TxRolledBack
  """
  Transaction rolled back successfully.
  """

primitive EndOfRows
  """
  Returned by fetch() when no more rows are available.
  """

type SqlValue is
  ( SqlNull | SqlBool
  | SqlTinyInt | SqlSmallInt | SqlInteger | SqlBigInt
  | SqlFloat | SqlText
  | SqlDate | SqlTime | SqlTimestamp | SqlDecimal )
  """
  Union of all supported SQL value types.
  """

primitive SqlNull
  """
  SQL NULL value.
  """
  fun string(): String val => "NULL"

class val SqlBool
  """
  SQL boolean value.
  """
  let value: Bool

  new val create(v: Bool) =>
    value = v

  fun string(): String iso^ =>
    value.string()

class val SqlTinyInt
  """
  SQL TINYINT. Wraps I8.
  """
  let value: I8

  new val create(v: I8) =>
    value = v

  fun string(): String iso^ =>
    value.string()

class val SqlSmallInt
  """
  SQL SMALLINT. Wraps I16.
  """
  let value: I16

  new val create(v: I16) =>
    value = v

  fun string(): String iso^ =>
    value.string()

class val SqlInteger
  """
  SQL INTEGER. Wraps I32.
  """
  let value: I32

  new val create(v: I32) =>
    value = v

  fun string(): String iso^ =>
    value.string()

class val SqlBigInt
  """
  SQL BIGINT. Wraps I64.
  """
  let value: I64

  new val create(v: I64) =>
    value = v

  fun string(): String iso^ =>
    value.string()

class val SqlFloat
  """
  Wraps F64. All float column types (REAL, DOUBLE, FLOAT) are read
  via SQL_C_DOUBLE and surfaced as F64.
  """
  let value: F64

  new val create(v: F64) =>
    value = v

  fun string(): String iso^ =>
    value.string()

class val SqlText
  """
  Wraps String val. Validated UTF-8 at the FFI boundary.
  """
  let value: String val

  new val create(v: String val) =>
    value = v

  fun string(): String iso^ =>
    value.string()

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

class val SqlDecimal
  """
  SQL NUMERIC/DECIMAL. Stored as string to preserve precision.
  """
  let value: String val

  new val create(v: String val) =>
    value = v

  fun string(): String iso^ =>
    value.string()
