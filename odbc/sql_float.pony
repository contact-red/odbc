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
