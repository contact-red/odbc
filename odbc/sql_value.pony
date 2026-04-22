trait val SqlValue
  """
  A value that can be bound to a prepared statement parameter slot.

  Each `SqlValue` owns its own storage — a fixed-width type points ODBC at
  `addressof self.value`, a text/decimal points at its `String`'s
  `cpointer()`, and composite types (date/time/timestamp) hold a packed
  `Array[U8]` buffer. Statement keeps the bound `SqlValue` alive until
  the next rebind so the pointer registered with `SQLBindParameter`
  remains valid for `SQLExecute`.

  Custom types typically only need to supply `c_data_type()` and
  `bind_to_odbc()`. `sql_type()` has a default mapping; override for
  types where the C and SQL types differ (e.g. DECIMAL carried as CHAR).

  `bind_to_odbc()` must call `@SQLBindParameter` directly — Pony's
  `addressof` operator is only usable in FFI argument positions, so
  no primitive helper can hide the FFI call for fixed-width types that
  bind via `addressof self.value`.
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

  fun len_or_indptr(): I64 => 0

  fun bind_to_odbc(
    hstmt: Pointer[None] tag,
    param_num: U16,
    ind_ptr: Pointer[I64] tag)
    : I16
