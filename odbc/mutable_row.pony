class ref MutableRow
  """
  Mutable row for zero-alloc fetch loops. Reused across fetches — column
  values are overwritten on each fetch_into() call.

  NOT sendable across actors (ref capability). For cross-actor use,
  copy values out or use the regular Row val from fetch().
  """

  var _columns: Array[SqlValue] ref

  new ref create(num_cols: USize = 0) =>
    _columns = Array[SqlValue](num_cols)

  fun ref _set_columns(columns: Array[SqlValue] ref) =>
    _columns = columns

  fun column(i: ColIndex): SqlValue ? =>
    """
    Polymorphic access. Raises error on out-of-range index.
    """
    let idx = (i.apply() - 1).usize()
    _columns(idx)?

  fun int(i: ColIndex): (I64 | SqlNull) ? =>
    """
    Read column as I64. Raises error on type mismatch or out of range.
    """
    match column(i)?
    | SqlNull => SqlNull
    | let v: SqlInt => v.value
    else error
    end

  fun float(i: ColIndex): (F64 | SqlNull) ? =>
    """
    Read column as F64. Raises error on type mismatch or out of range.
    """
    match column(i)?
    | SqlNull => SqlNull
    | let v: SqlFloat => v.value
    else error
    end

  fun text(i: ColIndex): (String val | SqlNull) ? =>
    """
    Read column as String val. Raises error on type mismatch or out of range.
    """
    match column(i)?
    | SqlNull => SqlNull
    | let v: SqlText => v.value
    else error
    end

  fun bool(i: ColIndex): (Bool | SqlNull) ? =>
    """
    Read column as Bool. Raises error on type mismatch or out of range.
    """
    match column(i)?
    | SqlNull => SqlNull
    | let v: SqlBool => v.value
    else error
    end

  fun date(i: ColIndex): (SqlDate | SqlNull) ? =>
    """
    Read column as SqlDate. Raises error on type mismatch or out of range.
    """
    match column(i)?
    | SqlNull => SqlNull
    | let v: SqlDate => v
    else error
    end

  fun time(i: ColIndex): (SqlTime | SqlNull) ? =>
    """
    Read column as SqlTime. Raises error on type mismatch or out of range.
    """
    match column(i)?
    | SqlNull => SqlNull
    | let v: SqlTime => v
    else error
    end

  fun timestamp(i: ColIndex): (SqlTimestamp | SqlNull) ? =>
    """
    Read column as SqlTimestamp. Raises error on type mismatch or out of range.
    """
    match column(i)?
    | SqlNull => SqlNull
    | let v: SqlTimestamp => v
    else error
    end

  fun decimal(i: ColIndex): (SqlDecimal | SqlNull) ? =>
    """
    Read column as SqlDecimal. Raises error on type mismatch or out of range.
    """
    match column(i)?
    | SqlNull => SqlNull
    | let v: SqlDecimal => v
    else error
    end

  fun is_null(i: ColIndex): Bool ? =>
    """
    True if column value is SQL NULL. Raises error on out of range.
    """
    match column(i)?
    | SqlNull => true
    else false
    end

  fun size(): USize =>
    """
    Number of columns in the row.
    """
    _columns.size()
