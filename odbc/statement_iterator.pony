class ref StatementIterator is Iterator[Row val]
  """
  Iterator adapter for Statement. Enables `for row in stmt.values() do`.
  FetchError raises error from next(). EndOfRows ends iteration.
  """
  let _stmt: Statement ref
  var _next_row: (Row val | None)
  var _done: Bool
  var _error: Bool

  new ref create(stmt: Statement ref) =>
    _stmt = stmt
    _next_row = None
    _done = false
    _error = false
    _prefetch()

  fun ref _prefetch() =>
    if _done or _error then return end
    match _stmt.fetch()
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
