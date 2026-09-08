#ifndef ODBC_STRUCTS_H
#define ODBC_STRUCTS_H

#include <sql.h>
#include <stddef.h>

size_t odbc_sizeof_date_struct(void);
size_t odbc_sizeof_time_struct(void);
size_t odbc_sizeof_timestamp_struct(void);

void odbc_decode_date(const void* buf,
    SQLSMALLINT* year, SQLUSMALLINT* month, SQLUSMALLINT* day);
void odbc_decode_time(const void* buf,
    SQLUSMALLINT* hour, SQLUSMALLINT* minute, SQLUSMALLINT* second);
void odbc_decode_timestamp(const void* buf,
    SQLSMALLINT* year, SQLUSMALLINT* month, SQLUSMALLINT* day,
    SQLUSMALLINT* hour, SQLUSMALLINT* minute, SQLUSMALLINT* second,
    SQLUINTEGER* fraction);

void odbc_encode_date(void* buf,
    SQLSMALLINT year, SQLUSMALLINT month, SQLUSMALLINT day);
void odbc_encode_time(void* buf,
    SQLUSMALLINT hour, SQLUSMALLINT minute, SQLUSMALLINT second);
void odbc_encode_timestamp(void* buf,
    SQLSMALLINT year, SQLUSMALLINT month, SQLUSMALLINT day,
    SQLUSMALLINT hour, SQLUSMALLINT minute, SQLUSMALLINT second,
    SQLUINTEGER fraction);

#endif
