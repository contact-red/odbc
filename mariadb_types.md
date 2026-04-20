# MariaDB 11.4 types → ODBC SQL type mapping

Reference table of MariaDB 11.4 server types with their MariaDB
Connector/ODBC mapping to ODBC SQL types.

| Category | MariaDB type | Aliases | ODBC SQL type |
|---|---|---|---|
| Integer | `tinyint` | `int1` | `SQL_TINYINT` |
| Integer | `tinyint unsigned` | — | `SQL_TINYINT` (unsigned C type) |
| Integer | `smallint` | `int2` | `SQL_SMALLINT` |
| Integer | `smallint unsigned` | — | `SQL_SMALLINT` (unsigned C type) |
| Integer | `mediumint` | `int3`, `middleint` | `SQL_INTEGER` |
| Integer | `mediumint unsigned` | — | `SQL_INTEGER` (unsigned C type) |
| Integer | `int` | `integer`, `int4` | `SQL_INTEGER` |
| Integer | `int unsigned` | — | `SQL_INTEGER` (unsigned C type) |
| Integer | `bigint` | `int8` | `SQL_BIGINT` |
| Integer | `bigint unsigned` | — | `SQL_BIGINT` (unsigned C type) |
| Fixed / float | `decimal(p,s)` | `dec`, `fixed`, `numeric` | `SQL_DECIMAL` |
| Fixed / float | `float` | `float4` | `SQL_REAL` |
| Fixed / float | `double` | `double precision`, `real`, `float8` | `SQL_DOUBLE` |
| Bit | `bit(1)` | — | `SQL_BIT` |
| Bit | `bit(n > 1)` | — | `SQL_BINARY` / `SQL_CHAR` (driver option) |
| Boolean | `boolean` | `bool` | `SQL_TINYINT` (alias for `tinyint(1)`) |
| Character | `char(n)` | `character(n)` | `SQL_CHAR` / `SQL_WCHAR` |
| Character | `varchar(n)` | `character varying(n)` | `SQL_VARCHAR` / `SQL_WVARCHAR` |
| Character | `tinytext` | — | `SQL_LONGVARCHAR` / `SQL_WLONGVARCHAR` |
| Character | `text` | — | `SQL_LONGVARCHAR` / `SQL_WLONGVARCHAR` |
| Character | `mediumtext` | `long varchar` | `SQL_LONGVARCHAR` / `SQL_WLONGVARCHAR` |
| Character | `longtext` | — | `SQL_LONGVARCHAR` / `SQL_WLONGVARCHAR` |
| Binary | `binary(n)` | — | `SQL_BINARY` |
| Binary | `varbinary(n)` | — | `SQL_VARBINARY` |
| Binary | `tinyblob` | — | `SQL_LONGVARBINARY` |
| Binary | `blob` | — | `SQL_LONGVARBINARY` |
| Binary | `mediumblob` | — | `SQL_LONGVARBINARY` |
| Binary | `longblob` | — | `SQL_LONGVARBINARY` |
| Date / time | `date` | — | `SQL_TYPE_DATE` |
| Date / time | `time` | — | `SQL_TYPE_TIME` |
| Date / time | `datetime` | — | `SQL_TYPE_TIMESTAMP` |
| Date / time | `timestamp` | — | `SQL_TYPE_TIMESTAMP` |
| Date / time | `year` | — | `SQL_SMALLINT` |
| Enum / set | `enum(...)` | — | `SQL_VARCHAR` |
| Enum / set | `set(...)` | — | `SQL_VARCHAR` |
| JSON | `json` | — | `SQL_LONGVARCHAR` |
| UUID | `uuid` (10.7+) | — | `SQL_GUID` / `SQL_CHAR(36)` (driver version dependent) |
| Network | `inet4` (10.10+) | — | `SQL_VARCHAR` (surfaced as `char(15)`) |
| Network | `inet6` (10.5+) | — | `SQL_VARCHAR` (surfaced as `char(39)`) |
| Spatial | `geometry` | — | `SQL_LONGVARBINARY` |
| Spatial | `point`, `linestring`, `polygon` | — | `SQL_LONGVARBINARY` |
| Spatial | `multipoint`, `multilinestring`, `multipolygon` | — | `SQL_LONGVARBINARY` |
| Spatial | `geometrycollection` | — | `SQL_LONGVARBINARY` |

## Notes

- MariaDB stores `json` as `longtext` with a validity `CHECK`; the driver
  therefore surfaces it as `SQL_LONGVARCHAR`, not a distinct JSON type.
- `boolean` / `bool` is a synonym for `tinyint(1)`; it does not round-trip
  through the driver as `SQL_BIT`.
- `W`-prefixed types (`SQL_WCHAR`, `SQL_WVARCHAR`, `SQL_WLONGVARCHAR`) are
  used for columns with Unicode character sets (e.g. `utf8mb3`, `utf8mb4`);
  single-byte character sets surface the non-`W` variants.
- Signed vs. unsigned integers share a single `SQL_*` SQL type; the
  distinction appears in the bound C type (`SQL_C_S*` vs. `SQL_C_U*`).
- `BIT(n > 1)` handling depends on the `NO_BIGINT`/bit-representation DSN
  flags and driver version; treat it as binary bytes for portable code.
- The `NO_BIGINT` DSN option remaps `bigint` to `SQL_INTEGER` for clients
  that cannot consume 64-bit integers.
- `uuid` (10.7+) is a 128-bit native type. Recent MariaDB Connector/ODBC
  releases expose it as `SQL_GUID`; older versions surface it as
  `SQL_CHAR(36)` or `SQL_VARCHAR(36)`.
- Spatial columns are returned as WKB byte strings; parse client-side.
- MariaDB Connector/ODBC is derived from the MySQL Connector/ODBC type
  mapping; MySQL-only types (e.g. MySQL's `vector`) are not applicable.
