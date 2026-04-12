class ref _AliveFlag
  """
  Shared flag owned by Connection. Statements and Cursors hold a ref
  alias. When Connection closes, _alive is set to false. Children check
  via is_alive() before touching FFI handles.

  The ref reference gives ORCA a reference path from child to parent,
  ensuring the Connection's finalizer runs after its children's."""
  var _alive: Bool = true

  fun ref set_dead() =>
    _alive = false

  fun box is_alive(): Bool =>
    _alive
