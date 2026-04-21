primitive _NullabilityMap
  """
  Map the ODBC nullable indicator (SQL_NO_NULLS, SQL_NULLABLE,
  SQL_NULLABLE_UNKNOWN) to the library's Nullability tri-state.
  """
  fun apply(n: I16): Nullability =>
    if n == ODBCConstants.sql_no_nulls() then NoNulls
    elseif n == ODBCConstants.sql_nullable() then Nullable
    else NullableUnknown
    end
