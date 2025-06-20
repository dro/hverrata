#include "hverrata_main.h"
#include "hverrata_isr.h"
#include "hverrata_test.h"

//
// Default initialize all fields of the HV errata context.
//
VOID
HvErrataInitialize(
    _Out_ HV_ERRATA_CONTEXT* Context
    )
{
    //
    // Zero initialize the entire errata context by default.
    //
    HVERRATA_MEMSET( Context, 0, sizeof( *Context ) );
}

//
// Push the results of a test case to the error list upon failure.
//
static
VOID
HvErrataProcessTestResult(
    _Inout_ HV_ERRATA_CONTEXT*  Context,
    _Inout_ HV_ERRATA_TEST_TYPE TestType,
    _Inout_ UINT32              Result
    )
{
    if( ( Result != 0 ) && ( Context->ErrorCount < __crt_countof( Context->Errors ) ) ) {
        Context->Errors[ Context->ErrorCount++ ] = ( HV_ERRATA_ERROR ){
            .TestType             = TestType,
            .ErrorCode            = Result,
            .IsUnhandledInterrupt = ( Context->Test.InterruptAbort != 0 ),
            .InterruptVector      = Context->Test.InterruptVector,
            .InterruptErrorCode   = Context->Test.InterruptErrorCode,
            .InterruptRip         = Context->Test.InterruptRip,
            .InternalResults      = {
                Context->Test.ScratchResult0,
                Context->Test.ScratchResult1,
                Context->Test.ScratchResult2,
                Context->Test.ScratchResult3,
            }
        };
    }
}

//
// Attempt to execute all test cases and record any error results.
//
static
VOID
HvErrataExecuteTestCases(
    _Inout_ HV_ERRATA_CONTEXT* Context
    )
{
    HvErrataProcessTestResult( Context, HV_ERRATA_TEST_TYPE_PCID01,   HvErrataExecuteTest( Context, HvErrataPcid01 ) );
    HvErrataProcessTestResult( Context, HV_ERRATA_TEST_TYPE_PCID02,   HvErrataExecuteTest( Context, HvErrataPcid02 ) );
    HvErrataProcessTestResult( Context, HV_ERRATA_TEST_TYPE_CPUID01,  HvErrataExecuteTest( Context, HvErrataCpuid01 ) );
    HvErrataProcessTestResult( Context, HV_ERRATA_TEST_TYPE_CPUID02,  HvErrataExecuteTest( Context, HvErrataCpuid02 ) );
    HvErrataProcessTestResult( Context, HV_ERRATA_TEST_TYPE_VMX01,    HvErrataExecuteTest( Context, HvErrataVmx01 ) );
    HvErrataProcessTestResult( Context, HV_ERRATA_TEST_TYPE_VMX02,    HvErrataExecuteTest( Context, HvErrataVmx02 ) );
    HvErrataProcessTestResult( Context, HV_ERRATA_TEST_TYPE_XSTATE01, HvErrataExecuteTest( Context, HvErrataXState01 ) );
    HvErrataProcessTestResult( Context, HV_ERRATA_TEST_TYPE_XSTATE02, HvErrataExecuteTest( Context, HvErrataXState02 ) );
    HvErrataProcessTestResult( Context, HV_ERRATA_TEST_TYPE_XSTATE03, HvErrataExecuteTest( Context, HvErrataXState03 ) );
    HvErrataProcessTestResult( Context, HV_ERRATA_TEST_TYPE_XSTATE04, HvErrataExecuteTest( Context, HvErrataXState04 ) );
    HvErrataProcessTestResult( Context, HV_ERRATA_TEST_TYPE_XSTATE05, HvErrataExecuteTest( Context, HvErrataXState05 ) );
    HvErrataProcessTestResult( Context, HV_ERRATA_TEST_TYPE_CR01,     HvErrataExecuteTest( Context, HvErrataCr01 ) );
    HvErrataProcessTestResult( Context, HV_ERRATA_TEST_TYPE_CR02,     HvErrataExecuteTest( Context, HvErrataCr02 ) );
    HvErrataProcessTestResult( Context, HV_ERRATA_TEST_TYPE_CR03,     HvErrataExecuteTest( Context, HvErrataCr03 ) );
    HvErrataProcessTestResult( Context, HV_ERRATA_TEST_TYPE_INVD01,   HvErrataExecuteTest( Context, HvErrataInvd01 ) );
}

//
// Set up an internal IDT entry.
// this is used to set up all supported IDT entries to their corresponding dispatchers,
// which will push their corresponding interrupt vector numbers before executing the real
// generic interrupt handler function.
//
static
VOID
HvErrataSetInterruptDispatcher(
    _Out_ INTERRUPT_GATE_DESCRIPTOR_64*  Entry,
    _In_  UINT16                         CsSelector,
    _In_  HV_ERRATA_INTERRUPT_DISPATCHER Dispatcher
    )
{
    Entry->Reserved0                = 0;
    Entry->Reserved1                = 0;
    Entry->Reserved2                = 0;
    Entry->Present                  = 1;
    Entry->InterruptStackTable      = 0;
    Entry->SegmentSelector          = CsSelector;
    Entry->Type                     = 0xE; /* 64-bit mode interrupt gate. */
    Entry->DescriptorPrivilegeLevel = 0;
    Entry->OffsetLow                = ( UINT16 )( ( UINT_PTR )Dispatcher & 0xFFFF );
    Entry->OffsetMiddle             = ( UINT16 )( ( ( UINT_PTR )Dispatcher & 0xFFFF0000 ) >> 16 );
    Entry->OffsetHigh               = ( UINT32 )( ( ( UINT_PTR )Dispatcher & 0xFFFFFFFF00000000 ) >> 32 );
}

//
// Set up the internal IDT used during testcase execution with all dispatchers.
//
static
VOID
HvErrataSetupIdt(
    _Inout_ HV_ERRATA_CONTEXT* Context,
    _In_    UINT16             CsSelector
    )
{
    HvErrataSetInterruptDispatcher( &Context->Idt[ 0 ],  CsSelector, HvErrataIsrDispatch0 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 1 ],  CsSelector, HvErrataIsrDispatch1 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 2 ],  CsSelector, HvErrataIsrDispatch2 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 3 ],  CsSelector, HvErrataIsrDispatch3 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 4 ],  CsSelector, HvErrataIsrDispatch4 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 5 ],  CsSelector, HvErrataIsrDispatch5 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 6 ],  CsSelector, HvErrataIsrDispatch6 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 7 ],  CsSelector, HvErrataIsrDispatch7 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 8 ],  CsSelector, HvErrataIsrDispatch8 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 9 ],  CsSelector, HvErrataIsrDispatch9 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 10 ], CsSelector, HvErrataIsrDispatch10 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 11 ], CsSelector, HvErrataIsrDispatch11 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 12 ], CsSelector, HvErrataIsrDispatch12 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 13 ], CsSelector, HvErrataIsrDispatch13 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 14 ], CsSelector, HvErrataIsrDispatch14 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 15 ], CsSelector, HvErrataIsrDispatch15 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 16 ], CsSelector, HvErrataIsrDispatch16 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 17 ], CsSelector, HvErrataIsrDispatch17 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 18 ], CsSelector, HvErrataIsrDispatch18 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 19 ], CsSelector, HvErrataIsrDispatch19 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 20 ], CsSelector, HvErrataIsrDispatch20 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 21 ], CsSelector, HvErrataIsrDispatch21 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 22 ], CsSelector, HvErrataIsrDispatch22 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 23 ], CsSelector, HvErrataIsrDispatch23 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 24 ], CsSelector, HvErrataIsrDispatch24 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 25 ], CsSelector, HvErrataIsrDispatch25 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 26 ], CsSelector, HvErrataIsrDispatch26 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 27 ], CsSelector, HvErrataIsrDispatch27 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 28 ], CsSelector, HvErrataIsrDispatch28 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 29 ], CsSelector, HvErrataIsrDispatch29 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 30 ], CsSelector, HvErrataIsrDispatch30 );
    HvErrataSetInterruptDispatcher( &Context->Idt[ 31 ], CsSelector, HvErrataIsrDispatch31 );
}

//
// Set up environment for tests, and execute all tests.
//
_Success_( return )
BOOLEAN
static
HvErrataExecuteInternal(
    _Inout_ HV_ERRATA_CONTEXT* Context
    )
{
    UINT64                       Pml4eIndex;
    UINT64*                      Pml4;
    UINT64                       Cr3;
    UINT64*                      Pml4e;
    UINT64                       FrameAddress;
    DESCRIPTOR_TABLE_REGISTER_64 OldIdtr;
    DESCRIPTOR_TABLE_REGISTER_64 Idtr;

    //
    // Search for a free PML4E entry in the current page-tables.
    // This code is designed to run under UEFI-BS environment where only the BSP is currently active,
    // and all page-tables are identity mapped.
    //
    Cr3  = __readcr3();
    Pml4 = ( VOID* )( Cr3 & ~( ( UINT64 )0xFFF ) );
    for( Pml4eIndex = 2; Pml4eIndex < 512; Pml4eIndex++ ) {
        Pml4e = &Pml4[ Pml4eIndex ];
        if( ( *Pml4e & PTE_64_PRESENT_FLAG ) == 0 ) {
            break;
        }
    }

    //
    // If we fail to find a free PML4E to reuse for our internal tests, bail out.
    // We could always search for a free PDPT/PD/PT, but this should never happen.
    //
    if( *Pml4e & PTE_64_PRESENT_FLAG ) {
        return FALSE;
    }

    //
    // Set up our internal scratch page table entries.
    // This creates two 4KiB PTEs in the first PDPTE/PDE/PT of the found free PML4E.
    //
    FrameAddress              = ( ( ( UINT64 )&Context->ScratchPdpt[ 0 ] ) & PTE_64_PFN_MASK ); /* Point PML4E to PDPTE 0 */
    *Pml4e                    = ( PTE_64_PRESENT_FLAG | PTE_64_WRITE_FLAG | FrameAddress );
    FrameAddress              = ( ( ( UINT64 )&Context->ScratchPd[ 0 ] ) & PTE_64_PFN_MASK ); /* Point PDPTE 0 to scratch PD table. */
    Context->ScratchPdpt[ 0 ] = ( PTE_64_PRESENT_FLAG | PTE_64_WRITE_FLAG | FrameAddress );
    FrameAddress              = ( ( ( UINT64 )&Context->ScratchPt[ 0 ] ) & PTE_64_PFN_MASK ); /* Point PDE 0 to scratch PT table. */
    Context->ScratchPd[ 0 ]   = ( PTE_64_PRESENT_FLAG | PTE_64_WRITE_FLAG | FrameAddress );
    FrameAddress              = ( ( ( UINT64 )&Context->ScratchPageMemory[ 0 ] ) & PTE_64_PFN_MASK ); /* Point PTE 0 to scratch page 0 memory. */
    Context->ScratchPt[ 0 ]   = ( PTE_64_PRESENT_FLAG | PTE_64_WRITE_FLAG | FrameAddress );
    FrameAddress              = ( ( ( UINT64 )&Context->ScratchPageMemory[ 4096 ] ) & PTE_64_PFN_MASK ); /* Point PTE 1 to scratch page 1 memory. */
    Context->ScratchPt[ 1 ]   = ( PTE_64_PRESENT_FLAG | PTE_64_WRITE_FLAG | FrameAddress );
    
    //
    // Set up default values of the shared context that is passed to all internal test cases.
    //
    Context->Test.ScratchPage0    = ( ( CHAR8* )( Pml4eIndex * 0x8000000000 ) + 0 );
    Context->Test.ScratchPage1    = ( ( CHAR8* )( Pml4eIndex * 0x8000000000 ) + 4096 );
    Context->Test.ScratchPage0Pte = &Context->ScratchPt[ 0 ];
    Context->Test.ScratchPage1Pte = &Context->ScratchPt[ 1 ];
    Context->Test.ScratchPage0Pa  = ( UINT64 )&Context->ScratchPageMemory[ 0 ];
    Context->Test.ScratchPage1Pa  = ( UINT64 )&Context->ScratchPageMemory[ 4096 ];

    //
    // Flush any possible cached translation information for the two new scratch page PTEs.
    //
    __invlpg( Context->Test.ScratchPage0 );
    __invlpg( Context->Test.ScratchPage1 );

    //
    // Set up the IDT to be used while executing test cases.
    //
    HvErrataSetupIdt( Context, HvErrataArchReadCsSelector() );
    __sidt( &OldIdtr );

    //
    // Switch to the internal test case IDT.
    //
    Idtr.Base  = ( UINT64 )Context->Idt;
    Idtr.Limit = ( sizeof( Context->Idt ) - 1 );
    __lidt( &Idtr );

    //
    // Execute all test cases with our newly set up processor context.
    //
    HvErrataExecuteTestCases( Context );

    //
    // Switch back to the original IDT.
    //
    __lidt( &OldIdtr );

    //
    // Clear the PML4E that we temporarily used for tests.
    //
    *Pml4e = 0;
    return TRUE;
}

//
// Execute all test cases.
//
_Success_( return )
BOOLEAN
HvErrataExecute(
    _Inout_ HV_ERRATA_CONTEXT* Context
    )
{
    UINT64  RFlags;
    BOOLEAN Success;

    //
    // Set up all required processor state and execute all test cases.
    // Disable interrupts during all tests, we don't want to have the scheduler (if any)
    // steal the processor out from underneath us, especially because we are internally 
    // allocating page table entries without involving the bookkeeping of the OS.
    //
    RFlags = __readeflags();
    __writeeflags( RFlags & ~RFLAGS_IF );
    Success = HvErrataExecuteInternal( Context );
    __writeeflags( RFlags );

    //
    // Handle failure to set up execution of the tests.
    // This doesn't indicate failure of any test cases, just internal startup failure.
    //
    if( Success == FALSE ) {
        return FALSE;
    }

    return ( Context->ErrorCount == 0 );
}