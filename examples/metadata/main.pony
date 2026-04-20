use "lib:odbc"
use "../../odbc"

actor Main
  new create(env: Env) =>
    env.out.print("=== ODBC Prepare-Time Metadata Example ===\n")

    let dsn_name =
      try env.args(1)?
      else "psqlred"
      end

    match \exhaustive\ Odbc.connect(Dsn("DSN=" + dsn_name))
    | let conn: Connection =>
      env.out.print("Connected")

      conn.exec("DROP TABLE IF EXISTS _odbc_meta_example")

      let ct =
        "CREATE TABLE _odbc_meta_example"
          + " (id INTEGER NOT NULL,"
          + " name VARCHAR(32),"
          + " created TIMESTAMP)"
      match \exhaustive\ conn.exec(ct)
      | let _: USize => env.out.print("Created table")
      | NoRowCount => env.out.print("Created table (no row count)")
      | let e: ExecError =>
        env.err.print("create: " + e.string())
        conn.close()
        return
      end

      // Parameter metadata on an INSERT.
      match \exhaustive\
        conn.prepare("INSERT INTO _odbc_meta_example VALUES (?, ?, ?)")
      | let stmt: Statement =>
        env.out.print("\nparameter_types() on INSERT:")
        match \exhaustive\ stmt.parameter_types()
        | let tags: Array[SqlTypeTag] val =>
          var i: USize = 1
          for t in tags.values() do
            env.out.print("  $" + i.string() + ": " + t.string())
            i = i + 1
          end
        | let e: MetadataError =>
          env.err.print("  " + e.string())
        end
        stmt.close()
      | let e: PrepareError =>
        env.err.print("prepare insert: " + e.string())
      end

      // Column metadata on a SELECT. Seeded for completeness; no fetch.
      match \exhaustive\
        conn.prepare(
          "SELECT id, name, created FROM _odbc_meta_example WHERE id > ?")
      | let stmt: Statement =>
        env.out.print("\nparameter_types() on SELECT:")
        match \exhaustive\ stmt.parameter_types()
        | let tags: Array[SqlTypeTag] val =>
          var i: USize = 1
          for t in tags.values() do
            env.out.print("  $" + i.string() + ": " + t.string())
            i = i + 1
          end
        | let e: MetadataError =>
          env.err.print("  " + e.string())
        end

        env.out.print("\ncolumn_types() on SELECT:")
        match \exhaustive\ stmt.column_types()
        | let cols: Array[ColumnMeta] val =>
          for col in cols.values() do
            env.out.print("  " + col.string())
          end
        | let e: MetadataError =>
          env.err.print("  " + e.string())
        end

        stmt.close()
      | let e: PrepareError =>
        env.err.print("prepare select: " + e.string())
      end

      conn.exec("DROP TABLE IF EXISTS _odbc_meta_example")
      conn.close()
      env.out.print("\nDone.")

    | let e: ConnectError =>
      env.err.print("connect: " + e.string())
    end
