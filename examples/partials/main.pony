use "lib:odbc"
use "../../odbc"

actor Main
  let env: Env

  new create(env': Env) =>
    env = env'

    try
      let conn: Connection =
        a_transaction(Odbc.connect(Dsn("DSN=psqlred")) as Connection)?
      conn.close()
      env.out.print("transaction succeeded")
    else
      env.out.print("Something failed")
    end

  fun a_transaction(conn: Connection): Connection ? =>
    conn
      .> exec_p("DROP TABLE IF EXISTS tut_tx")?
      .> exec_p(
        "CREATE TABLE tut_tx "
          + "(id INTEGER PRIMARY KEY, label VARCHAR(32))")?

      .> begin_p()?
      .> exec_p("INSERT INTO tut_tx VALUES (1, 'alpha')")?
      .> exec_p("INSERT INTO tut_tx VALUES (2, 'bravo')")?
      .> commit_p()?

