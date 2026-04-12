// ODBC FFI declarations for unixODBC.
// All pointer parameters use Pointer[None] tag — ODBC handles are opaque void*.

use "lib:odbc"

// Handle management
use @SQLAllocHandle[I16](handle_type: I16, input_handle: Pointer[None] tag,
  output_handle_ptr: Pointer[None] tag)
use @SQLFreeHandle[I16](handle_type: I16, handle: Pointer[None] tag)

// Environment
use @SQLSetEnvAttr[I16](env_handle: Pointer[None] tag, attribute: I32,
  value_ptr: USize, string_length: I32)

// Connection
use @SQLDriverConnect[I16](dbc: Pointer[None] tag, hwnd: Pointer[None] tag,
  in_conn_str: Pointer[None] tag, in_len: I16,
  out_conn_str: Pointer[None] tag, out_max: I16,
  out_len: Pointer[None] tag, driver_completion: U16)
use @SQLDisconnect[I16](dbc: Pointer[None] tag)
use @SQLSetConnectAttr[I16](dbc: Pointer[None] tag, attribute: I32,
  value_ptr: USize, string_length: I32)
use @SQLEndTran[I16](handle_type: I16, handle: Pointer[None] tag,
  completion_type: I16)

// Statement
use @SQLExecDirect[I16](stmt: Pointer[None] tag, sql: Pointer[None] tag,
  text_len: I32)
use @SQLPrepare[I16](stmt: Pointer[None] tag, sql: Pointer[None] tag,
  text_len: I32)
use @SQLExecute[I16](stmt: Pointer[None] tag)
use @SQLNumParams[I16](stmt: Pointer[None] tag, param_count: Pointer[None] tag)
use @SQLBindParameter[I16](stmt: Pointer[None] tag, param_num: U16,
  input_output_type: I16, value_type: I16,
  param_type: I16, column_size: U64,
  decimal_digits: I16, param_value: Pointer[None] tag,
  buffer_length: I64, strlen_or_ind: Pointer[None] tag)

// Result set
use @SQLNumResultCols[I16](stmt: Pointer[None] tag,
  col_count: Pointer[None] tag)
use @SQLDescribeCol[I16](stmt: Pointer[None] tag, col: U16,
  col_name: Pointer[None] tag, col_name_max: I16,
  col_name_len: Pointer[None] tag, data_type: Pointer[None] tag,
  col_size: Pointer[None] tag, decimal_digits: Pointer[None] tag,
  nullable: Pointer[None] tag)
use @SQLBindCol[I16](stmt: Pointer[None] tag, col: U16,
  target_type: I16, target_value: Pointer[None] tag,
  buffer_length: I64, strlen_or_ind: Pointer[None] tag)
use @SQLFetch[I16](stmt: Pointer[None] tag)
use @SQLGetData[I16](stmt: Pointer[None] tag, col: U16,
  target_type: I16, target_value: Pointer[None] tag,
  buffer_length: I64, strlen_or_ind: Pointer[None] tag)
use @SQLRowCount[I16](stmt: Pointer[None] tag,
  row_count: Pointer[None] tag)
use @SQLFreeStmt[I16](stmt: Pointer[None] tag, option: U16)

// Cancellation
use @SQLCancel[I16](stmt: Pointer[None] tag)

// C stdlib
use @memcpy[Pointer[None] tag](dst: Pointer[None] tag, src: Pointer[None] tag,
  n: USize)

// Diagnostics
use @SQLGetDiagRec[I16](handle_type: I16, handle: Pointer[None] tag,
  rec_number: I16, sqlstate: Pointer[None] tag,
  native_error: Pointer[None] tag,
  message_text: Pointer[None] tag, buffer_length: I16,
  text_length: Pointer[None] tag)


primitive _ODBC
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
