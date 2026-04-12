use "../../odbc"

actor Main
  new create(env: Env) =>
    env.out.print("=== ODBC Basic Example ===\n")

    // Connect
    match Odbc.connect(Dsn("DSN=" + try env.args(1)? else "psqlred" end))
    | let conn: Connection =>
      env.out.print("Connected to PostgreSQL")

      // DDL
      match conn.exec("DROP TABLE IF EXISTS _odbc_example")
      | let e: ExecError => env.err.print("drop: " + e.string())
      end

      match conn.exec("CREATE TABLE _odbc_example (id INTEGER, name VARCHAR(32), price DOUBLE PRECISION)")
      | let _: USize => env.out.print("Created table")
      | None => env.out.print("Created table (no row count)")
      | let e: ExecError => env.err.print("create: " + e.string()); conn.close(); return
      end

      // Insert via exec
      match conn.exec("INSERT INTO _odbc_example VALUES (1, 'widget', 9.99)")
      | let n: USize => env.out.print("Inserted " + n.string() + " row")
      | let e: ExecError => env.err.print("insert: " + e.string())
      end

      // Query
      match conn.query("SELECT id, name, price FROM _odbc_example")
      | let cursor: Cursor =>
        while true do
          match cursor.fetch()
          | let row: Row =>
            try
              let id = row.int(ColIndex(1))?
              let name = row.text(ColIndex(2))?
              let price = row.float(ColIndex(3))?
              env.out.print("  id=" + match id
                | let v: I64 => v.string()
                | SqlNull => "NULL"
                end
                + " name=" + match name
                | let v: String val => v
                | SqlNull => "NULL"
                end
                + " price=" + match price
                | let v: F64 => v.string()
                | SqlNull => "NULL"
                end)
            else
              env.err.print("  column read error")
            end
          | EndOfRows => break
          | let e: FetchError => env.err.print("fetch: " + e.string()); break
          end
        end
        cursor.close()
      | let e: ExecError => env.err.print("query: " + e.string())
      end

      // Cleanup
      conn.exec("DROP TABLE IF EXISTS _odbc_example")
      conn.close()
      env.out.print("\nDone.")

    | let e: ConnectError =>
      env.err.print("connect: " + e.string())
    end
