class val SqlRaw is SqlValue
  """
  Escape hatch for SQL types this library doesn't natively map to a typed
  SqlValue. Carries the raw bytes the driver returned, the SQL type code
  it reported, and the indicator (byte length, or SQL_NULL_DATA if the
  cell was NULL but for some reason still surfaced as SqlRaw).

  Read path: produced by `_ColumnBindings` for any column whose declared
  SQL type isn't recognized.

  Write path: binds the bytes back as `SQL_C_BINARY` with the original
  `sql_type_code`. Faithful round-trip when the destination column accepts
  binary input for that SQL type; behavior when it doesn't is driver-
  specific.
  """
  let sql_type_code: I16
  let bytes: Array[U8] val
  let indicator: I64

  new val create(
    sql_type_code': I16,
    bytes': Array[U8] val,
    indicator': I64)
  =>
    sql_type_code = sql_type_code'
    bytes = bytes'
    indicator = indicator'

  fun string(): String iso^ =>
    recover iso
      String
        .> append("Raw(sql_type=")
        .> append(sql_type_code.string())
        .> append(", ")
        .> append(bytes.size().string())
        .> append(" bytes)")
    end

  fun c_data_type(): I16 => ODBCConstants.c_binary()
  fun sql_type(): I16 => sql_type_code
  fun len_or_indptr(): I64 => bytes.size().i64()

  fun bind_to_odbc(
    hstmt: Pointer[None] tag,
    param_num: U16,
    ind_ptr: Pointer[I64] tag)
    : I16
  =>
    let n = bytes.size()
    @SQLBindParameter(
      hstmt, param_num,
      ODBCConstants.sql_param_input(),
      c_data_type(), sql_type(),
      n.u64(), I16(0),
      bytes.cpointer(), n.i64(),
      ind_ptr)
