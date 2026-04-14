use "pony_test"

class val DriverProfile
  """
  Per-driver capabilities and SQL dialect differences for integration tests.
  Set ODBC_TEST_DRIVER=postgresql|mariadb|sqlite to select a profile.
  Defaults to postgresql when unset.
  """
  let name: String val
  let has_decimal: Bool
  let large_text_sizes: Array[USize] val
  let huge_text_col_type: String val

  new val postgresql() =>
    name = "postgresql"
    has_decimal = true
    large_text_sizes = [as USize:
      100; 2000; 4000; 4095; 4096; 5000; 8000; 10240; 20000; 100000]
    huge_text_col_type = "TEXT"

  new val mariadb() =>
    name = "mariadb"
    has_decimal = true
    large_text_sizes = [as USize:
      100; 2000; 4000; 4095; 4096; 5000; 8000; 10240; 20000]
    huge_text_col_type = "LONGTEXT"

  new val sqlite() =>
    name = "sqlite"
    has_decimal = false
    large_text_sizes = [as USize:
      100; 2000; 4000; 4095; 4096; 5000; 8000; 10240; 20000]
    huge_text_col_type = "TEXT"

primitive _TestDriver
  fun apply(h: TestHelper): DriverProfile =>
    let driver = _env_var(h, "ODBC_TEST_DRIVER")
    match driver
    | "mariadb" => DriverProfile.mariadb()
    | "sqlite" => DriverProfile.sqlite()
    else
      DriverProfile.postgresql()
    end

  fun _env_var(h: TestHelper, key: String val): String val =>
    let prefix: String val = key + "="
    let prefix_len = prefix.size().isize()
    let vars = h.env.vars
    var i: USize = 0
    while i < vars.size() do
      try
        let v = vars(i)?
        if v.substring(0, prefix_len) == prefix then
          return v.substring(prefix_len)
        end
      end
      i = i + 1
    end
    ""
