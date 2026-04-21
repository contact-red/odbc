trait val SqlValue
  """
  A value that can be bound to a prepared statement parameter slot.

  Statement owns the per-parameter scratch buffer and grows it when
  `required_size()` exceeds the current capacity. On each bind, Statement
  asks the value to populate that buffer and then to bind itself to the
  driver via `bind_to_odbc()`.

  Custom types typically only need to supply `c_data_type()`, `sql_type()`,
  `required_size()`, `populate_buffer()`, and (for variable-width types)
  `len_or_indptr()`. The default `bind_to_odbc()` wires those through
  `SQLBindParameter` correctly for standard input parameters. Override it
  only for non-standard binding protocols (e.g. `SQL_DATA_AT_EXEC`,
  output parameters, unusual `col_size` rules).
  """
  fun c_data_type(): I16

  fun sql_type(): I16 =>
    """
    SQL type the driver should interpret the parameter as. Default maps
    from `c_data_type()` using the obvious 1:1 pairing; override when the
    SQL type differs (e.g. DECIMAL stored as a C string).
    """
    match c_data_type()
    | ODBCConstants.c_bit()            => ODBCConstants.sql_bit()
    | ODBCConstants.c_stinyint()       => ODBCConstants.sql_tinyint()
    | ODBCConstants.c_sshort()         => ODBCConstants.sql_smallint()
    | ODBCConstants.c_slong()          => ODBCConstants.sql_integer()
    | ODBCConstants.c_sbigint()        => ODBCConstants.sql_bigint()
    | ODBCConstants.c_double()         => ODBCConstants.sql_double()
    | ODBCConstants.c_type_date()      => ODBCConstants.sql_type_date()
    | ODBCConstants.c_type_time()      => ODBCConstants.sql_type_time()
    | ODBCConstants.c_type_timestamp() => ODBCConstants.sql_type_timestamp()
    else ODBCConstants.sql_varchar()
    end

  fun required_size(): USize => 0
  fun populate_buffer(buf: Array[U8]) => None
  fun len_or_indptr(): I64 => 0

  fun bind_to_odbc(
    hstmt: Pointer[None] tag,
    param_num: U16,
    buf: Array[U8],
    ind_ptr: Pointer[I64] tag)
    : I16
  =>
    """
    Default: bind the parameter as a standard ODBC input parameter.
    `col_size` follows ODBC's convention — the byte length for character
    data (minimum 1), zero for fixed-width types.
    """
    let c_type = c_data_type()
    let col_size: U64 =
      if c_type == ODBCConstants.c_char() then
        let ind = len_or_indptr()
        if ind > 0 then ind.u64() else 1 end
      else
        0
      end
    _SqlBindParameter(
      hstmt, param_num, c_type, sql_type(), col_size, buf, ind_ptr)

primitive _SqlBindParameter
  """
  Thin wrapper around @SQLBindParameter. Exists because Pony forbids FFI
  calls directly from trait default methods; calling a primitive helper
  that makes the FFI call is allowed.
  """
  fun apply(
    hstmt: Pointer[None] tag,
    param_num: U16,
    c_type: I16,
    sql_type: I16,
    col_size: U64,
    buf: Array[U8],
    ind_ptr: Pointer[I64] tag)
    : I16
  =>
    @SQLBindParameter(
      hstmt,
      param_num,
      ODBCConstants.sql_param_input(),
      c_type,
      sql_type,
      col_size,
      0,
      buf.cpointer(),
      buf.size().i64(),
      ind_ptr)
