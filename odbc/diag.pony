use "pony-ffi"

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

    // 6 bytes = 5-char SQLSTATE + null terminator. SQLGetDiagRec writes
    // a fixed-width SQLSTATE so there's no length out-param for it.
    let state_buf = CBuffer(6)
    // I16 backs SQLGetDiagRec's text_length out-param.
    let msg_buf = CBuffer[I16](_max_message_bytes())
    let mbox = msg_buf.written_size_ptr()

    let records: Array[DiagRecord] iso = recover iso Array[DiagRecord] end
    var rec_num: I16 = 1

    while rec_num <= _max_records() do
      state_buf.reset()
      msg_buf.reset()

      var native: I32 = 0

      let rc =
        @SQLGetDiagRec(
        handle_type,
        handle,
        rec_num,
        state_buf.ptr(),
        addressof native,
        msg_buf.ptr(),
        _max_message_bytes().i16(),
        addressof mbox.value)

      if not ODBCConstants.ok(rc) then break end

      // SQLSTATE is always 5 chars; the trailing byte is the null terminator.
      state_buf.set_written_size(5)
      let state: String val =
        try state_buf.copy_string()? else "" end

      // copy_string_truncated clamps to capacity when the driver reports a
      // longer text_length than the buffer holds, matching the prior
      // substring(0, min(msg_len, cap)) behavior.
      let msg_partial: String val =
        try msg_buf.copy_string_truncated()? else "" end

      let msg: String val =
        if mbox.value.usize() > _max_message_bytes() then
          msg_partial + "...[truncated]"
        else
          msg_partial
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
