use "lib:odbc"
use "pony_test"
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
    test.property(_RowIntAccessorProperty)
    test.property(_RowFloatAccessorProperty)
    test.property(_RowTextAccessorProperty)
    test.property(_RowBoolAccessorProperty)
    test.property(_RowNullProperty)
    test.property(_RowOutOfRangeProperty)
    test.property(_SqlstateClassifierProperty)
    test.property(_DescribeParamClassifierProperty)
    test.property(_ErrorRedactionProperty)
    test.property(_SqlValueRoundtripProperty)
    test.property(_MaxColumnBytesValidProperty)
    test.property(_MaxColumnBytesInvalidProperty)
    test.property(_MaxColumnBytesMixedProperty)

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
    test(_LargeTextGenRoundtripTest)
    test(_TextTruncationDetectionTest)
    test(_BinaryTypesTest)
    test(_BindBinaryTest)
    test(_LargeBinaryRoundtripTest)
    test(_DbSessionTest)
    test(_MetadataParamTypesTest)
    test(_MetadataColumnTypesTest)
    test(_MetadataEmptyTest)
    test(_MetadataClosedTest)
