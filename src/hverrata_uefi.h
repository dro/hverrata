#pragma once

#include "hverrata_platform.h"

//
// Base UEFI types.
//
typedef UINTN RETURN_STATUS;
typedef RETURN_STATUS EFI_STATUS;
typedef UINT64 EFI_PHYSICAL_ADDRESS;

//
// Base EFI API calling convention
//
#define EFIAPI __stdcall

//
// Basic EFI statuses used internally.
//
#define EFI_SUCCESS      ((EFI_STATUS)0)
#define EFI_DEVICE_ERROR ((EFI_STATUS)0x8000000000000007)

//
// EFI status helper macros.
//
#define EFI_ERROR(Status) (((INTN)(RETURN_STATUS)(Status)) < 0)

//
// UEFI memory allocation types used for EFI_ALLOCATE_PAGES.
//
typedef enum _EFI_ALLOCATE_TYPE {
    AllocateAnyPages,
    AllocateMaxAddress,
    AllocateAddress,
    MaxAllocateType
} EFI_ALLOCATE_TYPE;

//
// UEFI memory types.
//
typedef enum _EFI_MEMORY_TYPE {
    EfiReservedMemoryType = 0,
    EfiLoaderCode,
    EfiLoaderData,
    EfiBootServicesCode,
    EfiBootServicesData,
    EfiRuntimeServicesCode,
    EfiRuntimeServicesData,
    EfiConventionalMemory,
    EfiUnusableMemory,
    EfiACPIReclaimMemory,
    EfiACPIMemoryNVS,
    EfiMemoryMappedIO,
    EfiMemoryMappedIOPortSpace,
    EfiPalCode,
    EfiPersistentMemory,
    EfiMaxMemoryType
} EFI_MEMORY_TYPE;

//
// Data structure that precedes all of the standard EFI table types.
//
typedef struct _EFI_TABLE_HEADER {
    UINT64 Signature;
    UINT32 Revision;
    UINT32 HeaderSize;
    UINT32 CRC32;
    UINT32 Reserved;
} EFI_TABLE_HEADER;

//
// EFI boot services table.
//
typedef struct _EFI_BOOT_SERVICES EFI_BOOT_SERVICES;

//
// Allocates memory pages from the system.
//
typedef
EFI_STATUS
( EFIAPI* EFI_ALLOCATE_PAGES )(
    _In_    EFI_ALLOCATE_TYPE     Type,
    _In_    EFI_MEMORY_TYPE       MemoryType,
    _In_    UINTN                 Pages,
    _Inout_ EFI_PHYSICAL_ADDRESS* Memory
    );

//
// Frees memory pages.
//
typedef
EFI_STATUS
( EFIAPI* EFI_FREE_PAGES )(
    _In_ EFI_PHYSICAL_ADDRESS Memory,
    _In_ UINTN                Pages
    );

//
// EFI boot services table.
// Note: the rest of the structure is currently omitted.
//
struct _EFI_BOOT_SERVICES {
    EFI_TABLE_HEADER   Hdr;
    VOID*              RaiseTPL;
    VOID*              RestoreTPL;
    EFI_ALLOCATE_PAGES AllocatePages;
    EFI_FREE_PAGES     FreePages;
    VOID*              GetMemoryMap;
    VOID*              AllocatePool;
    VOID*              FreePool;
};

//
// The minimum required protocol for any handle supplied as the ConsoleOut or StandardError device.
//
typedef struct _EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL;

//
// Write a string to the output device.
//
typedef
EFI_STATUS
( EFIAPI* EFI_TEXT_STRING )(
    _In_   EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL* This,
    _In_z_ CHAR16*                          String
    );

//
// The minimum required protocol for any handle supplied as the ConsoleOut or StandardError device.
//
struct _EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL {
    VOID*           Reset;
    EFI_TEXT_STRING OutputString;
    VOID*           TestString;
    VOID*           QueryMode;
    VOID*           SetMode;
    VOID*           SetAttribute;
    VOID*           ClearScreen;
    VOID*           SetCursorPosition;
    VOID*           EnableCursor;
    VOID*           Mode;
};

//
// EFI system table.
//
typedef struct _EFI_SYSTEM_TABLE {
    EFI_TABLE_HEADER                  Hdr;
    CHAR16*                           FirmwareVendor;
    UINT32                            FirmwareRevision;
    VOID*                             ConsoleInHandle;
    VOID*                             ConIn;
    VOID*                             ConsoleOutHandle;
    EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*  ConOut;
    VOID*                             StandardErrorHandle;
    EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*  StdErr;
    struct _EFI_RUNTIME_SERVICES*     RuntimeServices;
    struct _EFI_BOOT_SERVICES*        BootServices;
    UINTN                             NumberOfTableEntries;
    struct _EFI_CONFIGURATION_TABLE*  ConfigurationTable;
} EFI_SYSTEM_TABLE;

//
// Allocate resource for the errata test system and execute all tests.
//
EFI_STATUS
HvErrataUefiExecute(
	_Inout_ EFI_SYSTEM_TABLE* System
	);