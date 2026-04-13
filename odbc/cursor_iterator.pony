class ref CursorIterator is Iterator[Row val]
  """
  Iterator adapter for Cursor. Enables `for row in cursor.values() do`.
  FetchError raises error from next(). EndOfRows ends iteration.
  """
  let _cursor: Cursor ref
  var _next_row: (Row val | None)
  var _done: Bool
  var _error: Bool

  new ref create(cursor: Cursor ref) =>
    _cursor = cursor
    _next_row = None
    _done = false
    _error = false
    _prefetch()

  fun ref _prefetch() =>
    """
    Fetch the next row and cache it. Sets _done on EndOfRows,
    _error on FetchError.
    """
    if _done or _error then return end
    match \exhaustive\ _cursor.fetch()
    | let row: Row => _next_row = row
    | EndOfRows => _done = true; _next_row = None
    | let _: FetchError => _error = true; _next_row = None
    end

  fun ref has_next(): Bool =>
    not (_done or _error)

  fun ref next(): Row val ? =>
    match _next_row
    | let row: Row =>
      _next_row = None
      _prefetch()
      row
    else
      error
    end
