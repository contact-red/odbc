# PostgreSQL 14.5 types → ODBC SQL type mapping

Reference table of PostgreSQL 14.5 types with their psqlODBC-driver mapping to
ODBC SQL types.

## Numeric

| PostgreSQL type | Aliases | ODBC SQL type |
|---|---|---|
| `smallint` | `int2` | `SQL_SMALLINT` |
| `integer` | `int`, `int4` | `SQL_INTEGER` |
| `bigint` | `int8` | `SQL_BIGINT` |
| `decimal` | `numeric` | `SQL_NUMERIC` |
| `real` | `float4` | `SQL_REAL` |
| `double precision` | `float8` | `SQL_DOUBLE` |
| `smallserial` | `serial2` | `SQL_SMALLINT` |
| `serial` | `serial4` | `SQL_INTEGER` |
| `bigserial` | `serial8` | `SQL_BIGINT` |
| `money` | — | `SQL_DOUBLE` (legacy) / `SQL_VARCHAR` |

## Character / text

| PostgreSQL type | Aliases | ODBC SQL type |
|---|---|---|
| `character(n)` | `char(n)` | `SQL_CHAR` |
| `character varying(n)` | `varchar(n)` | `SQL_VARCHAR` |
| `text` | — | `SQL_LONGVARCHAR` |
| `"char"` (1-byte internal) | — | `SQL_CHAR` |
| `name` | — | `SQL_VARCHAR` |

## Binary

| PostgreSQL type | ODBC SQL type |
|---|---|
| `bytea` | `SQL_LONGVARBINARY` |

## Date / time

| PostgreSQL type | Aliases | ODBC SQL type |
|---|---|---|
| `date` | — | `SQL_TYPE_DATE` |
| `time` | `time without time zone` | `SQL_TYPE_TIME` |
| `time with time zone` | `timetz` | `SQL_TYPE_TIME` (or `SQL_VARCHAR`) |
| `timestamp` | `timestamp without time zone` | `SQL_TYPE_TIMESTAMP` |
| `timestamp with time zone` | `timestamptz` | `SQL_TYPE_TIMESTAMP` |
| `interval` | — | `SQL_INTERVAL_*` / `SQL_VARCHAR` |

## Boolean

| PostgreSQL type | Aliases | ODBC SQL type |
|---|---|---|
| `boolean` | `bool` | `SQL_BIT` |

## Bit string

| PostgreSQL type | Aliases | ODBC SQL type |
|---|---|---|
| `bit(n)` | — | `SQL_BIT` (n=1) / `SQL_VARCHAR` |
| `bit varying(n)` | `varbit` | `SQL_VARCHAR` |

## UUID / XML / JSON

| PostgreSQL type | ODBC SQL type |
|---|---|
| `uuid` | `SQL_GUID` |
| `xml` | `SQL_LONGVARCHAR` |
| `json` | `SQL_LONGVARCHAR` |
| `jsonb` | `SQL_LONGVARCHAR` |

## Network address

| PostgreSQL type | ODBC SQL type |
|---|---|
| `cidr` | `SQL_VARCHAR` |
| `inet` | `SQL_VARCHAR` |
| `macaddr` | `SQL_VARCHAR` |
| `macaddr8` | `SQL_VARCHAR` |

## Geometric

| PostgreSQL type | ODBC SQL type |
|---|---|
| `point`, `line`, `lseg`, `box`, `path`, `polygon`, `circle` | `SQL_VARCHAR` |

## Text search

| PostgreSQL type | ODBC SQL type |
|---|---|
| `tsvector` | `SQL_VARCHAR` |
| `tsquery` | `SQL_VARCHAR` |

## Range types

| PostgreSQL type | ODBC SQL type |
|---|---|
| `int4range`, `int8range`, `numrange` | `SQL_VARCHAR` |
| `tsrange`, `tstzrange`, `daterange` | `SQL_VARCHAR` |

## Multirange types (new in PG 14)

| PostgreSQL type | ODBC SQL type |
|---|---|
| `int4multirange`, `int8multirange`, `nummultirange` | `SQL_VARCHAR` |
| `tsmultirange`, `tstzmultirange`, `datemultirange` | `SQL_VARCHAR` |

## Object identifier types

| PostgreSQL type | ODBC SQL type |
|---|---|
| `oid` | `SQL_INTEGER` (unsigned 4-byte) |
| `regproc`, `regprocedure`, `regoper`, `regoperator` | `SQL_VARCHAR` |
| `regclass`, `regtype`, `regrole`, `regnamespace` | `SQL_VARCHAR` |
| `regconfig`, `regdictionary`, `regcollation` | `SQL_VARCHAR` |
| `xid`, `cid`, `tid`, `xid8` | `SQL_VARCHAR` / `SQL_INTEGER` |

## Log sequence

| PostgreSQL type | ODBC SQL type |
|---|---|
| `pg_lsn` | `SQL_VARCHAR` |
| `pg_snapshot` (replaces `txid_snapshot` in 14) | `SQL_VARCHAR` |

## Composite, enum, domain, array

| PostgreSQL kind | ODBC SQL type |
|---|---|
| `enum` | `SQL_VARCHAR` |
| User-defined composite | `SQL_VARCHAR` |
| `DOMAIN` | Maps to base type's ODBC type |
| Arrays (`anyarray`, `int[]`, …) | `SQL_VARCHAR` (serialized) |

## Pseudo-types (not storable)

`any`, `anyelement`, `anyarray`, `anynonarray`, `anyenum`, `anyrange`,
`anymultirange`, `anycompatible*`, `cstring`, `internal`, `language_handler`,
`fdw_handler`, `table_am_handler`, `index_am_handler`, `tsm_handler`, `record`,
`trigger`, `event_trigger`, `pg_ddl_command`, `void`, `unknown` — no direct
ODBC mapping; not exposed as column types.

## Notes

- Mappings reflect the psqlODBC driver's defaults. The `BoolsAsChar`,
  `TextAsLongVarchar`, `UnknownsAsLongVarchar`, and `MaxVarcharSize` DSN
  options can shift several of these (notably `bool`, `text`, `uuid`, and
  anything psqlODBC considers "unknown").
- `SQL_GUID` for `uuid` requires a recent psqlODBC; older versions reported it
  as `SQL_CHAR(36)`.
- `interval` exposure as `SQL_INTERVAL_*` depends on driver version and
  related DSN flags; many driver versions just surface it as `SQL_VARCHAR`.
