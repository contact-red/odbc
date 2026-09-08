#include "odbc_columns.h"

int odbc_describe_column(
    SQLHSTMT hstmt,
    SQLUSMALLINT col,
    SQLSMALLINT* out_sql_type,
    SQLSMALLINT* out_c_type,
    size_t* out_buf_size,
    size_t max_column_bytes)
{
    SQLCHAR name_buf[2];
    SQLSMALLINT name_len = 0;
    SQLSMALLINT data_type = 0;
    SQLULEN col_size = 0;
    SQLSMALLINT decimal_digits = 0;
    SQLSMALLINT nullable = 0;

    SQLDescribeCol(hstmt, col, name_buf, 2, &name_len,
        &data_type, &col_size, &decimal_digits, &nullable);

    *out_sql_type = data_type;

    switch (data_type) {
    case SQL_CHAR:
    case SQL_VARCHAR:
    case SQL_LONGVARCHAR:
    case SQL_NUMERIC:
    case SQL_DECIMAL:
    {
        *out_c_type = SQL_C_CHAR;
        size_t sz = (size_t)(col_size + 1);
        if (sz < 4096) sz = 4096;
        if (sz > max_column_bytes) sz = max_column_bytes;
        *out_buf_size = sz;
        return ODBC_COL_TEXT;
    }
    case SQL_BINARY:
    case SQL_VARBINARY:
    case SQL_LONGVARBINARY:
    {
        *out_c_type = SQL_C_BINARY;
        size_t sz = (size_t)col_size;
        if (sz < 4096) sz = 4096;
        if (sz > max_column_bytes) sz = max_column_bytes;
        *out_buf_size = sz;
        return ODBC_COL_BINARY;
    }
    case SQL_BIT:
        *out_c_type = SQL_C_BIT;
        *out_buf_size = 1;
        return ODBC_COL_FIXED;
    case SQL_TINYINT:
        *out_c_type = SQL_C_STINYINT;
        *out_buf_size = 1;
        return ODBC_COL_FIXED;
    case SQL_SMALLINT:
        *out_c_type = SQL_C_SSHORT;
        *out_buf_size = 2;
        return ODBC_COL_FIXED;
    case SQL_INTEGER:
        *out_c_type = SQL_C_SLONG;
        *out_buf_size = 4;
        return ODBC_COL_FIXED;
    case SQL_BIGINT:
        *out_c_type = SQL_C_SBIGINT;
        *out_buf_size = 8;
        return ODBC_COL_FIXED;
    case SQL_REAL:
    case SQL_FLOAT:
    case SQL_DOUBLE:
        *out_c_type = SQL_C_DOUBLE;
        *out_buf_size = 8;
        return ODBC_COL_FIXED;
    case SQL_TYPE_DATE:
        *out_c_type = SQL_C_TYPE_DATE;
        *out_buf_size = sizeof(DATE_STRUCT);
        return ODBC_COL_FIXED;
    case SQL_TYPE_TIME:
        *out_c_type = SQL_C_TYPE_TIME;
        *out_buf_size = sizeof(TIME_STRUCT);
        return ODBC_COL_FIXED;
    case SQL_TYPE_TIMESTAMP:
        *out_c_type = SQL_C_TYPE_TIMESTAMP;
        *out_buf_size = sizeof(TIMESTAMP_STRUCT);
        return ODBC_COL_FIXED;
    default:
        *out_c_type = 0;
        *out_buf_size = 1;
        return ODBC_COL_RAW;
    }
}
