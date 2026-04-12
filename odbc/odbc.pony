"""
# ODBC

Pony wrapper for unixODBC. Provides typed, safe access to ODBC data sources
with runtime state checking, redacted error diagnostics, and immutable Row
snapshots.

## Usage

```pony
use "odbc"

actor Main
  new create(env: Env) =>
    match Odbc.connect(Dsn("DSN=mydb"))
    | let conn: Connection =>
      match conn.exec("CREATE TABLE t (id INTEGER)")
      | let e: ExecError => env.err.print(e.string())
      end
      conn.close()
    | let e: ConnectError =>
      env.err.print(e.string())
    end
```
"""
