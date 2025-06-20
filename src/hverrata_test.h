#pragma once

#include "hverrata_main.h"

//
// All internal test case entrypoints must adhere to this type.
//
typedef
UINT32
( *HV_ERRATA_TEST_ROUTINE ) (
    _Inout_ HV_ERRATA_CONTEXT* Context
    );

//
// Execute an internal test case, this is always safely required
// handles backing up non-volatile C state that may be clobbered by test cases.
//
UINT32
HvErrataExecuteTest(
    _Inout_ HV_ERRATA_CONTEXT*     Context,
    _In_    HV_ERRATA_TEST_ROUTINE TestRoutine
    );

//
// Test basic PCID flushing semantics.
//
UINT32
HvErrataPcid01(
    _Inout_ HV_ERRATA_CONTEXT* Context
    );

//
// Test for proper support of invpcid if support for PCID is advertised through cpuid.
//
UINT32
HvErrataPcid02(
    _Inout_ HV_ERRATA_CONTEXT* Context
    );

// 
// Check for desynchronized CR4 bits in cpuid leaves 01H and 07H.
// 
UINT32
HvErrataCpuid01(
    _Inout_ HV_ERRATA_CONTEXT* Context
    );

// 
// Check for desynchronized maximum save state size in cpuid leaf 0Dh.
// 
UINT32
HvErrataCpuid02(
    _Inout_ HV_ERRATA_CONTEXT* Context
    );

// 
// Test VMX support and CR4.VMXE mutability.
// 
UINT32
HvErrataVmx01(
    _Inout_ HV_ERRATA_CONTEXT* Context
    );

// 
// Test VMX instruction behaviour in regards to the feature control register.
// 
UINT32
HvErrataVmx02(
    _Inout_ HV_ERRATA_CONTEXT* Context
    );

// 
// Check semantics of XCR0 bits that are required or are mutually inclusive in some way.
// 
UINT32
HvErrataXState01(
    _Inout_ HV_ERRATA_CONTEXT* Context
    );

// 
// Check semantics of XCR0 MPX bits on processors that do not support MPX.
// 
// 
UINT32
HvErrataXState02(
    _Inout_ HV_ERRATA_CONTEXT* Context
    );

//
// Check semantics of XCR0 bits that are erroneously treated as reserved due to
// the VMM not considering the actual host processor capabilities.
//
// 
UINT32
HvErrataXState03(
    _Inout_ HV_ERRATA_CONTEXT* Context
    );

// 
// Check semantics of XCR0 bits that should be treated as reserved but are not.
// 
UINT32
HvErrataXState04(
    _Inout_ HV_ERRATA_CONTEXT* Context
    );

//
// Check if the VMM lets us modify the host XCR0 in a way that would conflict with host XSAVE/XRSTOR.
//
UINT32
HvErrataXState05(
    _Inout_ HV_ERRATA_CONTEXT* Context
    );


//
// Test basic CR0 reserved bit semantics and invalid bit combinations.
//
UINT32
HvErrataCr01(
    _Inout_ HV_ERRATA_CONTEXT* Context
    );

//
// Test CR4 reserved bit handling.
//
UINT32
HvErrataCr02(
    _Inout_ HV_ERRATA_CONTEXT* Context
    );

//
// Test CR3 reserved semantics and PCID interactions.
//
UINT32
HvErrataCr03(
    _Inout_ HV_ERRATA_CONTEXT* Context
    );

//
// Check for unsafe usage of INVD within the host, allowing for corruption of internal VMM state.
//
UINT32
HvErrataInvd01(
    _Inout_ HV_ERRATA_CONTEXT* Context
    );
