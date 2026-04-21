class val ParamIndex
  """
  1-based parameter index. Bounds checking happens at bind time.
  """
  let _n: U16

  new val create(n: U16) =>
    _n = n

  fun apply(): U16 => _n

  fun string(): String iso^ =>
    _n.string()
