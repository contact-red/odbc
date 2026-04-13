class val DiagRecord
  """
  A single ODBC diagnostic record from SQLGetDiagRec.
  """
  let sqlstate: String val
  let native_code: I32
  let _message: String val

  new val create(
    sqlstate': String val,
    native_code': I32,
    message': String val)
  =>
    sqlstate = sqlstate'
    native_code = native_code'
    _message = message'

  fun message(): String val =>
    _message

  fun string(): String iso^ =>
    recover iso
      String
        .> append("[")
        .> append(sqlstate)
        .> append("] ")
        .> append(_message)
    end

type DiagChain is Array[DiagRecord] val

primitive _DiagHelper
  """
  Read diagnostic records from an ODBC handle.

  Caps: message length at 4096 bytes, chain length at 16 records.
  These are defense-in-depth limits against malicious/buggy drivers.
  """

  fun _max_message_bytes(): USize => 4096
  fun _max_records(): I16 => 16

  fun read(handle_type: I16, handle: Pointer[None] tag): DiagChain =>
    """
    Read up to 16 diagnostic records from an ODBC handle.
    """

    // Build arrays for FFI output — these must be ref so we can read them
    let state_buf: String ref = String(6)
    state_buf.insert_byte(0, 0); state_buf.insert_byte(0, 0)
    state_buf.insert_byte(0, 0); state_buf.insert_byte(0, 0)
    state_buf.insert_byte(0, 0); state_buf.insert_byte(0, 0)

    let msg_buf: String ref = String(_max_message_bytes())

    let records: Array[DiagRecord] iso = recover iso Array[DiagRecord] end
    var rec_num: I16 = 1

    while rec_num <= _max_records() do
      // Reset buffers
      state_buf.clear()
      var i: USize = 0
      while i < 6 do state_buf.push(0); i = i + 1 end
      msg_buf.clear()
      i = 0
      while i < _max_message_bytes() do msg_buf.push(0); i = i + 1 end

      var native: I32 = 0
      var msg_len: I16 = 0

      let rc =
        @SQLGetDiagRec(
        handle_type,
        handle,
        rec_num,
        state_buf.cpointer(),
        addressof native,
        msg_buf.cpointer(),
        _max_message_bytes().i16(),
        addressof msg_len)

      if not _ODBC.ok(rc) then break end

      // Extract SQLSTATE (5 chars)
      let state: String val = state_buf.substring(0, 5)

      // Extract message, capped
      let actual_len = msg_len.usize().min(_max_message_bytes())
      let msg: String val =
        if msg_len.usize() > _max_message_bytes() then
          msg_buf.substring(0, actual_len.isize()) + "...[truncated]"
        else
          msg_buf.substring(0, actual_len.isize())
        end

      records.push(DiagRecord(state, native, msg))
      rec_num = rec_num + 1
    end

    if rec_num > _max_records() then
      let trunc_msg: String val =
        recover val
          "diagnostic chain truncated at "
            + _max_records().string() + " records"
        end
      records.push(DiagRecord("00000", 0, trunc_msg))
    end

    consume records
