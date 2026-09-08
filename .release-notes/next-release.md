## Require ponyc 0.71.0

The minimum supported ponyc version is now 0.71.0. The test suite will not compile on earlier versions.

## Add SqlBinary type for binary columns

Binary columns (SQL_BINARY, SQL_VARBINARY, SQL_LONGVARBINARY) are now returned as `SqlBinary` values instead of falling through to the `SqlRaw` escape hatch. This covers PostgreSQL `bytea`, MariaDB `binary`/`varbinary`/`blob`, and SQLite `BLOB` columns.

`Row` and `MutableRow` gain a `binary()` accessor that returns `(Array[U8] val | SqlNull)`. Prepared statements accept `SqlBinary` as a bind parameter.

```pony
// Read binary data from a query result
match row.binary(ColIndex(1))?
| let v: Array[U8] val => use_bytes(v)
| SqlNull => handle_null()
end

// Bind binary data to a prepared statement
let bytes: Array[U8] val = [as U8: 0xDE; 0xAD; 0xBE; 0xEF]
stmt.bind(ParamIndex(1), SqlBinary(bytes))
```

