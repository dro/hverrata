#pragma once

//
// Base lowest granularity page size helpers.
//
#define PAGE_SIZE  0x1000
#define PAGE_MASK  0xFFF
#define PAGE_SHIFT 0xC

//
// Helper to convert a byte-size to page-count.
//
#define SIZE_TO_PAGES(ByteSize) \
	(((ByteSize) >> PAGE_SHIFT) + (((ByteSize) & PAGE_MASK) ? 1 : 0))

//
// Generic fields that apply to all PTE types.
//
#define PTE_64_PRESENT_FLAG 0x01
#define PTE_64_WRITE_FLAG   0x02
#define PTE_64_PFN_MASK     0xFFFFFFFFF000

//
// RFLAGS fields.
//
#define RFLAGS_IF 0x200

//
// 64-bit descriptor table register used for GDTR/IDTR.
//
#pragma pack(push, 1)
typedef struct _DESCRIPTOR_TABLE_REGISTER_64 {
	UINT16 Limit;
	UINT64 Base;
} DESCRIPTOR_TABLE_REGISTER_64;
#pragma pack(pop)

//
// 64-bit interrupt gate descriptor.
//
typedef struct _INTERRUPT_GATE_DESCRIPTOR_64 {
	UINT16 OffsetLow;
	UINT16 SegmentSelector;
	UINT32 InterruptStackTable : 3;
	UINT32 Reserved0 : 5;
	UINT32 Type : 4;
	UINT32 Reserved1 : 1;
	UINT32 DescriptorPrivilegeLevel : 2;
	UINT32 Present : 1;
	UINT32 OffsetMiddle : 16;
	UINT32 OffsetHigh;
	UINT32 Reserved2;
} INTERRUPT_GATE_DESCRIPTOR_64;