class ref CursorIterator is Iterator[(Row val | FetchError)]
  """
  Iterator adapter for Cursor. Enables `for result in cursor.values() do`.
  Yields Row values on success, FetchError on failure. EndOfRows ends
  iteration.
  """
  let _cursor: Cursor ref
  var _next: (Row val | FetchError | None)
  var _done: Bool

  new ref create(cursor: Cursor ref) =>
    _cursor = cursor
    _next = None
    _done = false
    _prefetch()

  fun ref _prefetch() =>
    """
    Fetch the next row and cache it. Sets _done on EndOfRows.
    FetchError is cached as a value to be yielded by next().
    """
    if _done then return end
    match \exhaustive\ _cursor.fetch()
    | let row: Row => _next = row
    | EndOfRows => _done = true; _next = None
    | let e: FetchError => _next = e; _done = true
    end

  fun ref has_next(): Bool =>
    _next isnt None

  fun ref next(): (Row val | FetchError) ? =>
    match _next
    | let row: Row =>
      _next = None
      _prefetch()
      row
    | let e: FetchError =>
      _next = None
      e
    else
      error
    end
