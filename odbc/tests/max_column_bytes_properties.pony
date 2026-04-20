use "pony_test"
use "pony_check"
use ".."

class val _MaxColBytesInput
  let n: USize
  let should_succeed: Bool

  new val create(n': USize, should_succeed': Bool) =>
    n = n'
    should_succeed = should_succeed'

class iso _MaxColumnBytesValidProperty is Property1[_MaxColBytesInput]
  fun name(): String =>
    "MaxColumnBytes accepts any value in [min(), max()]"

  fun gen(): Generator[_MaxColBytesInput] =>
    // Valid range: [4096, I64.max_value().usize()]. Bias toward the
    // realistic operational range (under 2 GiB) via a narrow picker
    // most of the time, with rare extreme boundary hits.
    Generator[_MaxColBytesInput](
      object is GenObj[_MaxColBytesInput]
        fun generate(rnd: Randomness): _MaxColBytesInput^ =>
          let which = rnd.usize(0, 9)
          let n =
            if which < 7 then
              rnd.usize(4096, 2_147_483_648)  // 4 KiB .. 2 GiB
            elseif which < 9 then
              // Floor and near-floor
              rnd.usize(4096, 8192)
            else
              // Ceiling
              I64.max_value().usize()
            end
          _MaxColBytesInput(n, true)
      end)

  fun property(input: _MaxColBytesInput, ph: PropertyHelper) =>
    try
      let m = MaxColumnBytes(input.n)?
      ph.assert_eq[USize](input.n, m.apply())
    else
      ph.fail("valid input " + input.n.string() + " was rejected")
    end

class iso _MaxColumnBytesInvalidProperty is Property1[_MaxColBytesInput]
  fun name(): String =>
    "MaxColumnBytes rejects any value outside [min(), max()]"

  fun gen(): Generator[_MaxColBytesInput] =>
    // Invalid generator covers both failure modes: below floor and
    // above ceiling. Oneof across the two keeps each branch exercised.
    Generator[_MaxColBytesInput](
      object is GenObj[_MaxColBytesInput]
        fun generate(rnd: Randomness): _MaxColBytesInput^ =>
          let too_small = rnd.bool()
          let n =
            if too_small then
              rnd.usize(0, 4095)
            else
              // (I64.max, U64.max]. Bias toward just-over-ceiling and
              // U64.max to exercise both edges.
              let which = rnd.usize(0, 3)
              match which
              | 0 => I64.max_value().usize() + 1
              | 1 => USize.max_value()
              else
                rnd.usize(I64.max_value().usize() + 1,
                  USize.max_value())
              end
            end
          _MaxColBytesInput(n, false)
      end)

  fun property(input: _MaxColBytesInput, ph: PropertyHelper) =>
    try
      let _ = MaxColumnBytes(input.n)?
      ph.fail("invalid input " + input.n.string() + " was accepted")
    end

class iso _MaxColumnBytesMixedProperty is Property1[_MaxColBytesInput]
  fun name(): String =>
    "MaxColumnBytes accepts iff input is within [min(), max()]"

  fun gen(): Generator[_MaxColBytesInput] =>
    // Mixed generator: draws from valid or invalid with equal weight.
    // The property is the strongest of the three — it asserts the
    // exact boundary between acceptance and rejection.
    Generator[_MaxColBytesInput](
      object is GenObj[_MaxColBytesInput]
        fun generate(rnd: Randomness): _MaxColBytesInput^ =>
          let n = rnd.usize(0, USize.max_value())
          let valid =
            (n >= 4096) and (n <= I64.max_value().usize())
          _MaxColBytesInput(n, valid)
      end)

  fun property(input: _MaxColBytesInput, ph: PropertyHelper) =>
    let outcome =
      try
        let _ = MaxColumnBytes(input.n)?
        true
      else
        false
      end
    ph.assert_eq[Bool](input.should_succeed, outcome,
      "boundary mismatch for n=" + input.n.string())
