type Nullability is (NoNulls | Nullable | NullableUnknown)
  """
  Tri-state nullability as reported by SQLDescribeCol/SQLDescribeParam.
  NullableUnknown is distinct from Nullable: the driver did not answer
  the question.
  """

primitive NoNulls
  fun string(): String val => "NOT NULL"

primitive Nullable
  fun string(): String val => "NULLABLE"

primitive NullableUnknown
  fun string(): String val => "nullability unknown"
