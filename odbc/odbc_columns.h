#ifndef ODBC_COLUMNS_H
#define ODBC_COLUMNS_H

#include <sql.h>
#include <sqlext.h>
#include <stddef.h>

#define ODBC_COL_RAW    0
#define ODBC_COL_TEXT   1
#define ODBC_COL_BINARY 2
#define ODBC_COL_FIXED  3

int odbc_describe_column(
    SQLHSTMT hstmt,
    SQLUSMALLINT col,
    SQLSMALLINT* out_sql_type,
    SQLSMALLINT* out_c_type,
    size_t* out_buf_size,
    size_t max_column_bytes);

#endif
