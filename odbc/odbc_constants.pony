primitive ODBCConstants
  """
  ODBC constants.
  """

  // Handle types
  fun handle_env(): I16 => 1
  fun handle_dbc(): I16 => 2
  fun handle_stmt(): I16 => 3

  // Return codes
  fun sql_success(): I16 => 0
  fun sql_success_with_info(): I16 => 1
  fun sql_error(): I16 => -1
  fun sql_invalid_handle(): I16 => -2
  fun sql_no_data(): I16 => 100

  // Environment attributes
  fun attr_odbc_version(): I32 => 200
  fun ov_odbc3(): USize => 3

  // Connection attributes
  fun attr_autocommit(): I32 => 102
  fun autocommit_on(): USize => 1
  fun autocommit_off(): USize => 0

  // Driver connect
  fun driver_noprompt(): U16 => 0

  // Transaction completion
  fun sql_commit(): I16 => 0
  fun sql_rollback(): I16 => 1

  // C data types
  fun c_char(): I16 => 1
  fun c_stinyint(): I16 => -26
  fun c_sshort(): I16 => -15
  fun c_slong(): I16 => -16
  fun c_sbigint(): I16 => -25
  fun c_double(): I16 => 8
  fun c_bit(): I16 => -7
  fun c_type_date(): I16 => 91
  fun c_type_time(): I16 => 92
  fun c_type_timestamp(): I16 => 93

  // SQL data types
  fun sql_char(): I16 => 1
  fun sql_varchar(): I16 => 12
  fun sql_longvarchar(): I16 => -1
  fun sql_tinyint(): I16 => -6
  fun sql_smallint(): I16 => 5
  fun sql_integer(): I16 => 4
  fun sql_bigint(): I16 => -5
  fun sql_real(): I16 => 7
  fun sql_float(): I16 => 6
  fun sql_double(): I16 => 8
  fun sql_bit(): I16 => -7
  fun sql_numeric(): I16 => 2
  fun sql_decimal(): I16 => 3
  fun sql_type_date(): I16 => 91
  fun sql_type_time(): I16 => 92
  fun sql_type_timestamp(): I16 => 93

  // Struct sizes (bytes)
  fun date_struct_size(): USize => 6
  fun time_struct_size(): USize => 6
  fun timestamp_struct_size(): USize => 16

  // SQLFreeStmt options
  fun sql_close_cursor(): U16 => 0
  fun sql_unbind(): U16 => 2
  fun sql_reset_params(): U16 => 3

  // SQLBindParameter direction
  fun sql_param_input(): I16 => 1

  // Column/parameter nullability (from SQLDescribeCol/SQLDescribeParam)
  fun sql_no_nulls(): I16 => 0
  fun sql_nullable(): I16 => 1
  fun sql_nullable_unknown(): I16 => 2

  // Null indicator
  fun sql_null_data(): I64 => -1
  fun sql_no_row_count(): I64 => -1

  // Null handle
  fun null_handle(): Pointer[None] tag => Pointer[None]

  // Helper: check if return code indicates success
  fun ok(rc: I16): Bool =>
    (rc == sql_success()) or (rc == sql_success_with_info())

  fun has_info(rc: I16): Bool =>
    rc == sql_success_with_info()
