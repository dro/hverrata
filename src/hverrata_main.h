#pragma once

#include "hverrata_platform.h"
#include "hverrata_ia32.h"

//
// Main test cases identifiers.
// Certain test cases may execute multiple sub-tests.
//
typedef enum _HV_ERRATA_TEST_TYPE {
    //
    // All internal errata test types.
    //
    HV_ERRATA_TEST_TYPE_NONE     = 0,
    HV_ERRATA_TEST_TYPE_PCID01   = 1,
    HV_ERRATA_TEST_TYPE_PCID02   = 2,
    HV_ERRATA_TEST_TYPE_CPUID01  = 3,
    HV_ERRATA_TEST_TYPE_CPUID02  = 4,
    HV_ERRATA_TEST_TYPE_VMX01    = 5,
    HV_ERRATA_TEST_TYPE_VMX02    = 6,
    HV_ERRATA_TEST_TYPE_XSTATE01 = 7,
    HV_ERRATA_TEST_TYPE_XSTATE02 = 8,
    HV_ERRATA_TEST_TYPE_XSTATE03 = 9,
    HV_ERRATA_TEST_TYPE_XSTATE04 = 10,
    HV_ERRATA_TEST_TYPE_XSTATE05 = 11,
    HV_ERRATA_TEST_TYPE_CR01     = 12,
    HV_ERRATA_TEST_TYPE_CR02     = 13,
    HV_ERRATA_TEST_TYPE_CR03     = 14,
    HV_ERRATA_TEST_TYPE_CR04     = 15,
    HV_ERRATA_TEST_TYPE_INVD01   = 16,

    //
    // Count of errata test types, used to determine the required size of the result array.
    //
    HV_ERRATA_MAX_TEST_TYPE_COUNT
} HV_ERRATA_TEST_TYPE;

//
// An individual error result pushed by a test case.
//
typedef struct _HV_ERRATA_ERROR {
    HV_ERRATA_TEST_TYPE TestType;
    UINT32              ErrorCode;
    UINT32              IsUnhandledInterrupt;
    UINT64              InternalResults[ 4 ];
    UINT64              InterruptVector;
    UINT64              InterruptErrorCode;
    UINT64              InterruptRip;
} HV_ERRATA_ERROR;

//
// Main test context containing all resources used for the testing process.
// This must always be allocated as identity mapped and contiguous in physical memory.
//
typedef struct _HV_ERRATA_CONTEXT {
    //
    // This is the shared test-case area of the context,
    // and must remain up-to-date with the structure definitions in the assembly files.
    // This structure must remain at the very start of the context.
    //
    struct {
        VOID*            ScratchPage0;
        VOID*            ScratchPage1;
        volatile UINT64* ScratchPage0Pte;
        volatile UINT64* ScratchPage1Pte;
        UINT64           ScratchPage0Pa;
        UINT64           ScratchPage1Pa;
        VOID*            EhHandler;
        VOID*            EhHandlerDefault;
        UINT64           EhHandlerDefaultRsp;
        UINT64           ScratchResult0;
        UINT64           ScratchResult1;
        UINT64           ScratchResult2;
        UINT64           ScratchResult3;
        UINT64           InterruptVector;
        UINT64           InterruptErrorCode;
        UINT64           InterruptAbort;
        UINT64           InterruptRip;
    } Test;

    //
    // Internal scratch page-table backing memory for one full PML4E.
    //
    _Alignas( PAGE_SIZE ) volatile UINT64 ScratchPdpt[ 512 ];
    _Alignas( PAGE_SIZE ) volatile UINT64 ScratchPd[ 512 ];
    _Alignas( PAGE_SIZE ) volatile UINT64 ScratchPt[ 512 ];

    //
    // Internal backing memory for the scratch pages.
    //
    _Alignas( PAGE_SIZE ) UINT8 ScratchPageMemory[ 8192 ];

    //
    // Internal IDT used while executing test cases.
    //
    INTERRUPT_GATE_DESCRIPTOR_64 Idt[ 32 ];

    //
    // Internal exception handler address stack buffer.
    //
    VOID* EhStackBuffer[ 1024 ];

    //
    // Testcase failure results.
    //
    HV_ERRATA_ERROR Errors[ HV_ERRATA_MAX_TEST_TYPE_COUNT + 1 ];
    SIZE_T          ErrorCount;
} HV_ERRATA_CONTEXT;

//
// Default initialize all fields of the HV errata context.
//
VOID
HvErrataInitialize(
    _Out_ HV_ERRATA_CONTEXT* Context
    );

//
// Execute all test cases.
//
_Success_( return )
BOOLEAN
HvErrataExecute(
    _Inout_ HV_ERRATA_CONTEXT* Context
    );