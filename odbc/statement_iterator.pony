class ref StatementIterator is Iterator[(Row val | FetchError)]
  """
  Iterator adapter for Statement. Enables `for result in stmt.values() do`.
  Yields Row values on success, FetchError on failure. EndOfRows ends
  iteration.
  """
  let _stmt: Statement ref
  var _next: (Row val | FetchError | None)
  var _done: Bool

  new ref create(stmt: Statement ref) =>
    _stmt = stmt
    _next = None
    _done = false
    _prefetch()

  fun ref _prefetch() =>
    if _done then return end
    match \exhaustive\ _stmt.fetch()
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
