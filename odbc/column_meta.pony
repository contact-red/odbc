class val ColumnMeta
  """
  Prepare-time metadata for one result column: name, SQL type tag,
  and nullability. Returned by Statement.column_types() after prepare().
  """
  let name: String val
  let type_tag: SqlTypeTag
  let nullable: Nullability

  new val create(
    name': String val,
    type_tag': SqlTypeTag,
    nullable': Nullability)
  =>
    name = name'
    type_tag = type_tag'
    nullable = nullable'

  fun string(): String iso^ =>
    recover iso
      String
        .> append(name)
        .> append(": ")
        .> append(type_tag.string())
        .> append(" (")
        .> append(nullable.string())
        .> append(")")
    end
