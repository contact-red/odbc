#include "odbc_structs.h"

size_t odbc_sizeof_date_struct(void) {
    return sizeof(DATE_STRUCT);
}

size_t odbc_sizeof_time_struct(void) {
    return sizeof(TIME_STRUCT);
}

size_t odbc_sizeof_timestamp_struct(void) {
    return sizeof(TIMESTAMP_STRUCT);
}

void odbc_decode_date(const void* buf,
    SQLSMALLINT* year, SQLUSMALLINT* month, SQLUSMALLINT* day)
{
    const DATE_STRUCT* d = (const DATE_STRUCT*)buf;
    *year = d->year;
    *month = d->month;
    *day = d->day;
}

void odbc_decode_time(const void* buf,
    SQLUSMALLINT* hour, SQLUSMALLINT* minute, SQLUSMALLINT* second)
{
    const TIME_STRUCT* t = (const TIME_STRUCT*)buf;
    *hour = t->hour;
    *minute = t->minute;
    *second = t->second;
}

void odbc_decode_timestamp(const void* buf,
    SQLSMALLINT* year, SQLUSMALLINT* month, SQLUSMALLINT* day,
    SQLUSMALLINT* hour, SQLUSMALLINT* minute, SQLUSMALLINT* second,
    SQLUINTEGER* fraction)
{
    const TIMESTAMP_STRUCT* ts = (const TIMESTAMP_STRUCT*)buf;
    *year = ts->year;
    *month = ts->month;
    *day = ts->day;
    *hour = ts->hour;
    *minute = ts->minute;
    *second = ts->second;
    *fraction = ts->fraction;
}

void odbc_encode_date(void* buf,
    SQLSMALLINT year, SQLUSMALLINT month, SQLUSMALLINT day)
{
    DATE_STRUCT* d = (DATE_STRUCT*)buf;
    d->year = year;
    d->month = month;
    d->day = day;
}

void odbc_encode_time(void* buf,
    SQLUSMALLINT hour, SQLUSMALLINT minute, SQLUSMALLINT second)
{
    TIME_STRUCT* t = (TIME_STRUCT*)buf;
    t->hour = hour;
    t->minute = minute;
    t->second = second;
}

void odbc_encode_timestamp(void* buf,
    SQLSMALLINT year, SQLUSMALLINT month, SQLUSMALLINT day,
    SQLUSMALLINT hour, SQLUSMALLINT minute, SQLUSMALLINT second,
    SQLUINTEGER fraction)
{
    TIMESTAMP_STRUCT* ts = (TIMESTAMP_STRUCT*)buf;
    ts->year = year;
    ts->month = month;
    ts->day = day;
    ts->hour = hour;
    ts->minute = minute;
    ts->second = second;
    ts->fraction = fraction;
}
