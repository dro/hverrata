#include "hverrata_main.h"
#include "hverrata_uefi.h"

//
// Output a string to the UEFI standard output console stream,
//
static
VOID
HvErrataUefiPrintString16(
    _Inout_ EFI_SYSTEM_TABLE* System,
    _In_z_  CHAR16*           String
    )
{
    System->ConOut->OutputString( System->ConOut, String );
}

//
// Output an integer to the UEFI standard output console stream.
//
static
VOID
HvErrataUefiPrintUInt64(
    _Inout_ EFI_SYSTEM_TABLE* System,
    _In_    UINT64            Integer
    )
{
    SIZE_T i;
    UINT64 IntegerScratch;
    CHAR16 Nibble;
    CHAR16 NibbleChar;
    CHAR16 ConvString[ 16 + 1 ];
    SIZE_T ConvStringSize;
    SIZE_T ConvStringOffset;

    //
    // Convert input integer to a hexadecimal string.
    // Nibbles will be outputted back to front,
    // ConvStringOffset will contain the start offset of the string.
    //
    IntegerScratch = Integer;
    for( i = 0; i < MIN( 16, sizeof( ConvString ) ); i++ ) {
        if( ( IntegerScratch == 0 ) && ( i != 0 ) ) {
            break;
        }
        Nibble = ( CHAR16 )( IntegerScratch & 0xF );
        NibbleChar = ( CHAR16 )( ( Nibble < 10 ) ? ( '0' + Nibble ) : ( 'a' + Nibble - 10 ) );
        ConvString[ 16 - i - 1 ] = NibbleChar;
        IntegerScratch >>= 4;
    }
    ConvStringSize = i;
    ConvStringOffset = ( 16 - ConvStringSize );
    ConvString[ 16 ] = '\0';

    //
    // Output the converted integer to the UEFI standard output stream.
    //
    System->ConOut->OutputString( System->ConOut, &ConvString[ ConvStringOffset ] );
}

//
// Allocate resource for the errata test system and execute all tests.
//
EFI_STATUS
EFIAPI
HvErrataUefiMain(
    _In_    VOID*             ImageHandle,
    _Inout_ EFI_SYSTEM_TABLE* System
    )
{
    EFI_STATUS           Status;
    HV_ERRATA_CONTEXT*   Errata;
    EFI_PHYSICAL_ADDRESS ErrataPa;
    BOOLEAN              Success;
    SIZE_T               i;
    SIZE_T               j;
    HV_ERRATA_ERROR*     Error;

    //
    // Allocate contiguous physical memory for the errata test context.
    // Must be page-aligned and contiguous in PM!
    //
    ErrataPa = 0;
    if( EFI_ERROR( Status = System->BootServices->AllocatePages( AllocateAnyPages,
                                                                 EfiBootServicesCode,
                                                                 SIZE_TO_PAGES( sizeof( *Errata ) ),
                                                                 &ErrataPa ) ) )
    {
        HvErrataUefiPrintString16( System, L"[HVERR] AllocatePages for backing test memory failed: " );
        HvErrataUefiPrintUInt64( System, Status );
        HvErrataUefiPrintString16( System, L"\r\n" );
        return Status;
    }
    Errata = ( VOID* )ErrataPa;

    //
    // Attempt to execute all errata tests, any errors will be outputted per-testcase to the error array.
    //
    HvErrataInitialize( Errata );
    Success = HvErrataExecute( Errata );

    //
    // Print information about any testcase errors if execution has failed.
    //
    if( Success == FALSE ) {
        for( i = 0; i < Errata->ErrorCount; i++ ) {
            Error = &Errata->Errors[ i ];
            HvErrataUefiPrintString16( System, L"[HVERR] Failed test (0x" );
            HvErrataUefiPrintUInt64( System, ( UINT64 )Error->TestType );
            HvErrataUefiPrintString16( System, L") with error code (0x" );
            HvErrataUefiPrintUInt64( System, ( UINT64 )Error->ErrorCode );
            HvErrataUefiPrintString16( System, L"Internal scratch result values:\r\n" );
            for( j = 0; j < COUNTOF( Error->InternalResults ); j++ ) {
                HvErrataUefiPrintString16( System, L"[HVERR]  0x" );
                HvErrataUefiPrintUInt64( System, ( UINT64 )j );
                HvErrataUefiPrintString16( System, L": 0x" );
                HvErrataUefiPrintUInt64( System, Error->InternalResults[ j ] );
            }
            if( Error->IsUnhandledInterrupt ) {
                HvErrataUefiPrintString16( System, L"[HVERR]  Test case aborted due to unhandled interrupt:\r\n" );
                HvErrataUefiPrintString16( System, L"[HVERR]     Vector:     0x" );
                HvErrataUefiPrintUInt64( System, Error->InterruptVector );
                HvErrataUefiPrintString16( System, L"\r\n[HVERR]     Error code: 0x" );
                HvErrataUefiPrintUInt64( System, Error->InterruptErrorCode );
                HvErrataUefiPrintString16( System, L"\r\n[HVERR]     Rip:        0x" );
                HvErrataUefiPrintUInt64( System, Errata->Errors[ i ].InterruptRip );
                HvErrataUefiPrintString16( System, L"\r\n" );
            }
        }
    } else {
        HvErrataUefiPrintString16( System, L"[HVERR] Passed all tests!\r\n" );
    }

    //
    // Release backing physical memory of the errata test context.
    //
    System->BootServices->FreePages( ErrataPa, SIZE_TO_PAGES( sizeof( *Errata ) ) );
    return ( Success ? EFI_SUCCESS : EFI_DEVICE_ERROR );
}