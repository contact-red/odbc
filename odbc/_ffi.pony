// ODBC FFI declarations for unixODBC.
// All pointer parameters use Pointer[None] tag — ODBC handles are opaque void*.

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
use @SQLDescribeParam[I16](stmt: Pointer[None] tag, param_num: U16,
  data_type: Pointer[None] tag, param_size: Pointer[None] tag,
  decimal_digits: Pointer[None] tag, nullable: Pointer[None] tag)
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
