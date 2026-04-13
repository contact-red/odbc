use "lib:odbc"
use "../../odbc"

actor Main
  new create(env: Env) =>
    env.out.print("=== ODBC Basic Example ===\n")

    let dsn_name =
      try env.args(1)?
      else "psqlred"
      end

    match \exhaustive\ Odbc.connect(Dsn("DSN=" + dsn_name))
    | let conn: Connection =>
      env.out.print("Connected")

      match conn.exec("DROP TABLE IF EXISTS _odbc_example")
      | let e: ExecError =>
        env.err.print("drop: " + e.string())
      end

      let ct =
        "CREATE TABLE _odbc_example"
          + " (id INTEGER, name VARCHAR(32),"
          + " price DOUBLE PRECISION)"
      match \exhaustive\ conn.exec(ct)
      | let _: USize =>
        env.out.print("Created table")
      | NoRowCount =>
        env.out.print("Created table (no row count)")
      | let e: ExecError =>
        env.err.print("create: " + e.string())
        conn.close()
        return
      end

      let ins =
        "INSERT INTO _odbc_example"
          + " VALUES (1, 'widget', 9.99)"
      match \exhaustive\ conn.exec(ins)
      | let n: USize =>
        env.out.print("Inserted " + n.string() + " row")
      | NoRowCount => None
      | let e: ExecError =>
        env.err.print("insert: " + e.string())
      end

      let sel =
        "SELECT id, name, price FROM _odbc_example"
      match \exhaustive\ conn.query(sel)
      | let cursor: Cursor =>
        for row in cursor.values() do
          try
            let id =
              match \exhaustive\ row.int(ColIndex(1))?
              | let v: I64 => v.string()
              | SqlNull => "NULL"
              end
            let name =
              match \exhaustive\ row.text(ColIndex(2))?
              | let v: String val => v
              | SqlNull => "NULL"
              end
            let price =
              match \exhaustive\ row.float(ColIndex(3))?
              | let v: F64 => v.string()
              | SqlNull => "NULL"
              end
            env.out.print(
              "  id=" + id
                + " name=" + name
                + " price=" + price)
          else
            env.err.print("  column read error")
          end
        end
        cursor.close()
      | let e: ExecError =>
        env.err.print("query: " + e.string())
      end

      conn.exec("DROP TABLE IF EXISTS _odbc_example")
      conn.close()
      env.out.print("\nDone.")

    | let e: ConnectError =>
      env.err.print("connect: " + e.string())
    end
