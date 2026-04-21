primitive ExecErrorClassifier
  """
  Classify ODBC errors into ExecErrorKind based on SQLSTATE class.
  """

  fun classify(diag: DiagChain): ExecErrorKind =>
    try
      let state = diag(0)?.sqlstate
      if state.size() >= 2 then
        let class2 =
          recover val
          let s = String(2)
          try s.push(state(0)?); s.push(state(1)?) end
          s
        end
        // SQLSTATE classes:
        // 08 = connection exception
        // 23 = integrity constraint violation
        // 42 = syntax error or access rule violation
        if class2 == "08" then return ConnectionLost end
        if class2 == "23" then return ConstraintViolation end
        if class2 == "42" then return SyntaxError end
      end
    end
    QueryError
