class val ColIndex
  """
  1-based column index. Bounds checking happens at row access time.
  """
  let _n: U16

  new val create(n: U16) =>
    _n = n

  fun apply(): U16 => _n

  fun string(): String iso^ =>
    _n.string()
