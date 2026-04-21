primitive _SqlTypeTagMap
  """
  Map an ODBC SQL type code (from SQLDescribeCol/SQLDescribeParam) to
  the library's SqlTypeTag. Types outside the mapped set become
  SqlTagUnknown with the raw code preserved for caller inspection.
  """
  fun apply(data_type: I16): SqlTypeTag =>
    match data_type
    | ODBCConstants.sql_bit() => SqlTagBool
    | ODBCConstants.sql_tinyint() => SqlTagTinyInt
    | ODBCConstants.sql_smallint() => SqlTagSmallInt
    | ODBCConstants.sql_integer() => SqlTagInteger
    | ODBCConstants.sql_bigint() => SqlTagBigInt
    | ODBCConstants.sql_real() => SqlTagFloat
    | ODBCConstants.sql_float() => SqlTagFloat
    | ODBCConstants.sql_double() => SqlTagFloat
    | ODBCConstants.sql_char() => SqlTagText
    | ODBCConstants.sql_varchar() => SqlTagText
    | ODBCConstants.sql_longvarchar() => SqlTagText
    | ODBCConstants.sql_type_date() => SqlTagDate
    | ODBCConstants.sql_type_time() => SqlTagTime
    | ODBCConstants.sql_type_timestamp() => SqlTagTimestamp
    | ODBCConstants.sql_numeric() => SqlTagDecimal
    | ODBCConstants.sql_decimal() => SqlTagDecimal
    else SqlTagUnknown(data_type)
    end
