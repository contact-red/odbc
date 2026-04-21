type SqlTypeTag is
  ( SqlTagBool
  | SqlTagTinyInt | SqlTagSmallInt | SqlTagInteger | SqlTagBigInt
  | SqlTagFloat | SqlTagText
  | SqlTagDate | SqlTagTime | SqlTagTimestamp | SqlTagDecimal
  | SqlTagUnknown )
  """
  Types-only tag union parallel to SqlValue. Describes a parameter's or
  column's SQL type as reported by the driver, independent of any
  particular value. SqlTagUnknown carries the raw ODBC type code for
  types outside the set this library maps to SqlValue.
  """

primitive SqlTagBool
  fun string(): String val => "Bool"

primitive SqlTagTinyInt
  fun string(): String val => "TinyInt"

primitive SqlTagSmallInt
  fun string(): String val => "SmallInt"

primitive SqlTagInteger
  fun string(): String val => "Integer"

primitive SqlTagBigInt
  fun string(): String val => "BigInt"

primitive SqlTagFloat
  fun string(): String val => "Float"

primitive SqlTagText
  fun string(): String val => "Text"

primitive SqlTagDate
  fun string(): String val => "Date"

primitive SqlTagTime
  fun string(): String val => "Time"

primitive SqlTagTimestamp
  fun string(): String val => "Timestamp"

primitive SqlTagDecimal
  fun string(): String val => "Decimal"

class val SqlTagUnknown
  """
  A SQL type reported by the driver that this library does not map to a
  SqlValue variant. Carries the raw ODBC SQL type code (see the SQL_*
  constants in the ODBC headers).
  """
  let raw_type: I16

  new val create(raw_type': I16) =>
    raw_type = raw_type'

  fun string(): String iso^ =>
    recover iso
      String
        .> append("Unknown(")
        .> append(raw_type.string())
        .> append(")")
    end
