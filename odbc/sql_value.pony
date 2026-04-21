type SqlValue is
  ( SqlNull | SqlBool
  | SqlTinyInt | SqlSmallInt | SqlInteger | SqlBigInt
  | SqlFloat | SqlText
  | SqlDate | SqlTime | SqlTimestamp | SqlDecimal )
  """
  Union of all supported SQL value types.
  """
