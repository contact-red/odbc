use "lib:odbc"
use "pony_test"
use "pony_check"
use ".."

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    """
    Register all tests.
    """
    // Pure Pony property tests (no driver needed)
    test(Property1UnitTest[_RowTestInput](_RowIntAccessorProperty))
    test(Property1UnitTest[_RowTestInput](_RowFloatAccessorProperty))
    test(Property1UnitTest[_RowTestInput](_RowTextAccessorProperty))
    test(Property1UnitTest[_RowTestInput](_RowBoolAccessorProperty))
    test(Property1UnitTest[USize](_RowNullProperty))
    test(Property1UnitTest[_RowOutOfRangeInput](_RowOutOfRangeProperty))
    test(Property1UnitTest[_SqlstateInput](_SqlstateClassifierProperty))
    test(Property1UnitTest[_DiagLeakInput](_ErrorRedactionProperty))
    test(Property1UnitTest[_SqlValueInput](_SqlValueRoundtripProperty))

    // Integration tests (need real drivers)
    test(_ConnectDisconnectTest)
    test(_ExecDdlTest)
    test(_QueryRoundtripTest)
    test(_NullRoundtripTest)
    test(_PreparedStatementTest)
    test(_StatementReuseTest)
    test(_TransactionTest)
    test(_ErrorPathsTest)
    test(_DoubleCloseTest)
    test(_CursorValuesTest)
    test(_StatementValuesTest)
    test(_DateTimeTypesTest)
    test(_DecimalTypesTest)
    test(_FetchIntoTest)
    test(_PartialFunctionTest)
    test(_BindDateTimeDecimalTest)
    test(_LargeTextRoundtripTest)
    test(_TextTruncationDetectionTest)
    test(_DbSessionTest)
