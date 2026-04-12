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


type RowCount is (USize | None)
  """
  Result of exec/execute_update. USize is affected row count.
  None means the driver returned SQL_NO_ROW_COUNT (-1).
  """


primitive EndOfRows
  """
  Returned by fetch() when no more rows are available.
  """


type SqlValue is (SqlNull | SqlBool | SqlInt | SqlFloat | SqlText)
  """
  Union of all supported SQL value types.
  """


primitive SqlNull
  """
  SQL NULL value.
  """
  fun string(): String val => "NULL"


class val SqlBool
  let value: Bool

  new val create(v: Bool) =>
    value = v

  fun string(): String iso^ =>
    value.string()


class val SqlInt
  """
  Wraps I64. All integer column types (SMALLINT, INTEGER, BIGINT) are
  read via SQL_C_SBIGINT and surfaced as I64. Platform-portable.
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
