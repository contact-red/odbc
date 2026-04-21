trait val SqlValue
  """
  A value that can be bound to a prepared statement parameter slot.

  Statement owns the per-parameter scratch buffer and grows it when
  `required_size()` exceeds the current capacity. On each bind, Statement
  asks the value to `populate_buffer()` and reads back the indicator
  (`len_or_indptr()`) and C type (`c_data_type()`) that SQLBindParameter
  needs.
  """
  fun c_data_type(): I16
  fun required_size(): USize => 0
  fun populate_buffer(buf: Array[U8]) => None
  fun len_or_indptr(): I64 => 0
