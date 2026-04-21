type RowCount is (USize | NoRowCount)
  """
  Result of exec/execute_update. USize is affected row count.
  NoRowCount means the driver returned SQL_NO_ROW_COUNT (-1).
  """

primitive NoRowCount
  """
  The driver did not report an affected row count.
  """
