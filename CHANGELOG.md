# Change Log

All notable changes to this project will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org/) and [Keep a CHANGELOG](http://keepachangelog.com/).

## [0.0.3] - 2026-04-22

### Fixed

- `Statement.close()` and `Cursor.close()` (and their finalizers) no
  longer call `SQLFreeHandle` on statement handles whose connection is
  already closed. The connection's `SQLFreeHandle(SQL_HANDLE_DBC)`
  freed those handles transitively, so the extra call was undefined
  behavior on a dangling handle.

### Added

- `Statement.parameter_types()` and `Statement.column_types()` for
  reading prepare-time metadata without executing the statement. Useful
  for build-time tools that validate SQL against a live database.
- `SqlTypeTag` union (parallel to `SqlValue`), `Nullability` tri-state
  (`NoNulls | Nullable | NullableUnknown`), and `ColumnMeta` value
  class in `types.pony`.
- `MetadataError` in `errors.pony`, including the
  `DriverDoesNotSupportDescribeParam` kind classified from SQLSTATE
  IM001/HYC00.
- `examples/metadata` demonstrating both calls against a prepared
  SELECT and INSERT.

## [0.0.2] - 2026-04-16

### Added

- Initial Version - Documentation at: [https://odbc.contact.red/](https://odbc.contact.red)

