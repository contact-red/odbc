primitive SqlNull is SqlValue
  """
  SQL NULL value.
  """
  fun string(): String val => "NULL"

  fun len_or_indptr(): I64 => ODBCConstants.sql_null_data()
  fun c_data_type(): I16   => ODBCConstants.c_char()
