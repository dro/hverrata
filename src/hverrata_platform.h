#pragma once

#include <stddef.h>
#include <stdint.h>
#include <inttypes.h>
#include <limits.h>
#include <sal.h>

//
// Include compiler intrinsic definitions on MSVC build.
//
#ifdef _MSC_VER
 #include <intrin.h>
#endif

//
// Fix missing SAL annotation for certain build configurations.
//
#ifndef _Frees_ptr_
 #define _Frees_ptr_
#endif

//
// Base integer types.
//
typedef int8_t        INT8;
typedef int16_t       INT16;
typedef int32_t       INT32;
typedef int64_t       INT64;
typedef uint8_t       UINT8;
typedef uint16_t      UINT16;
typedef uint32_t      UINT32;
typedef uint64_t      UINT64;
typedef int           INT;
typedef unsigned int  UINT;
typedef size_t        SIZE_T;
typedef intptr_t      INTN;
typedef intptr_t      INT_PTR;
typedef uintptr_t     UINT_PTR;
typedef uintptr_t     UINTN;
typedef char          CHAR;
typedef char          CHAR8;
typedef unsigned char UCHAR;
typedef unsigned char UCHAR8;
typedef wchar_t       CHAR16;
typedef UINT8         BOOLEAN;
typedef long          LONG;
typedef unsigned long ULONG;
#ifndef VOID
 typedef void         VOID;
#endif

//
// Boolean values.
//
#define TRUE  ((BOOLEAN)(1 == 1))
#define FALSE ((BOOLEAN)(0 == 1))

//
// Helper macros.
// 
#define MAX(a,b) (((a) > (b)) ? (a) : (b))
#define MIN(a,b) (((a) < (b)) ? (a) : (b))
#define COUNTOF(Array) (sizeof((Array)) / sizeof((Array[0])))
#define CONTAINING_RECORD(Address, Type, Field) ((Type*)((CHAR*)(Address) - offsetof(Type, Field)))

//
// Internal memset to avoid generated calls to unlinked CRT memset.
//
#define HVERRATA_MEMSET(Dest, Value, Size) __stosb((UCHAR*)(Dest), (Value), (Size))

//
// Helper to read the current CS segment selector being used by the processor.
//
UINT16
HvErrataArchReadCsSelector(
    VOID
    );