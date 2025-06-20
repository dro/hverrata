.CODE

include hverrata_common.inc

;
; CPUID EAX_01_ECX_00 table to CR4 bit mapping table.
; Byte 0 = CR4 bit, Byte 1 = CPUID register, Byte 2 = CPUID bit, Byte 3 = Padding.
;

CpuidEax01ToCr4BitTable:
    db 9 , 3, 24, 0 ; OSFXSR
    db 10, 3, 25, 0 ; OSXMMEXCPT
    db 13, 2, 5 , 0 ; VMXE
    db 14, 2, 6 , 0 ; SMXE
    db 17, 2, 17, 0 ; PCIDE
    db 18, 2, 26, 0 ; OSXSAVE
CpuidEax01ToCr4BitTableEnd:
CPUID_EAX_01_TO_CR4_BIT_COUNT equ ((CpuidEax01ToCr4BitTableEnd - CpuidEax01ToCr4BitTable) / 4)

;
; CPUID EAX_07_ECX_00 to CR4 bit mapping table.
; Byte 0 = CR4 bit, Byte 1 = CPUID register, Byte 2 = CPUID bit, Byte 3 = Padding.
;

CpuidEax07ToCr4BitTable:
    db 11, 2, 2 , 0 ; UMIP
    db 12, 2, 16, 0 ; LA57
    db 16, 1, 0 , 0 ; FSGSBASE
    db 20, 1, 7 , 0 ; SMEP
    db 21, 1, 20, 0 ; SMAP
    db 22, 2, 3 , 0 ; PKE
    db 23, 2, 7 , 0 ; CET
    db 24, 2, 31, 0 ; PKS
CpuidEax07ToCr4BitTableEnd:
CPUID_EAX_07_TO_CR4_BIT_COUNT equ ((CpuidEax07ToCr4BitTableEnd - CpuidEax07ToCr4BitTable) / 4)

;
; CPUID EAX_07_ECX_01 to CR4 bit mapping table.
; CR4 bit, CPUID register, CPUID bit.
;

CpuidEax07Ecx01ToCr4BitTable:
    db 25, 3, 13, 0 ; UINTR
    db 28, 0, 26, 0 ; LAM_SUP
CpuidEax07Ecx01ToCr4BitTableEnd:
CPUID_EAX_07_ECX_01_TO_CR4_BIT_COUNT equ ((CpuidEax07Ecx01ToCr4BitTableEnd - CpuidEax07Ecx01ToCr4BitTable) / 4)

;
; Test basic CR0 reserved bits and invalid bit combinations.
; r15 = HV_ERRATA_CONTEXT*
;

HvErrataCr01 PROC

; Attempting to set any reserved bits in CR0[63:32] results in a general-protection exception.

    mov      rax, 0FFFFFFFF00000000h
    mov      rcx, rax
    mov      rax, cr0
    or       rax, rcx
    lea      rcx, [HighReservedException]
    EH_SET   r15, rcx
    mov      cr0, rax
    EH_CLEAR r15
    xor      eax, eax
    inc      eax
    ret
HighReservedException:

; Attempting to set any reserved bits in CR0[31:0] is ignored.

    mov      rax, cr0
    or       rax, 1FFAFFC0h
    lea      rcx, [LowReservedException]
    EH_SET   r15, rcx
    mov      cr0, rax
    EH_CLEAR r15
    jmp      NoLowReservedException
LowReservedException:
    xor eax, eax
    inc eax
    inc eax
    ret
NoLowReservedException:

; If an attempt is made to clear CR0.PG while IA-32e mode is enabled, a general-protection fault is triggered.
    
    mov      rax, cr0
    and      rax, 7FFFFFFFh
    lea      rcx, [PgClearException]
    EH_SET   r15, rcx
    mov      cr0, rax
    EH_CLEAR r15
    mov      eax, 3
    ret
PgClearException:

; If an attempt is made to set the PG flag to 1 when the PE flag is set to 0, #GP(0).

    mov      rax, cr0
    and      rax, 3FFFFFFFh
    or       rax, 80000000h
    lea      rcx, [PgPeMismatchException]
    EH_SET   r15, rcx
    mov      cr0, rax
    EH_CLEAR r15
    mov      eax, 4
    ret
PgPeMismatchException:

; If an attempt is made to set the CD flag to 0 when the NW flag is set to 1, #GP(0).

    mov      rax, cr0
    and      rax, 0BFFFFFFFh
    or       rax, 20000000h
    lea      rcx, [CdNwMismatchException]
    EH_SET   r15, rcx
    mov      cr0, rax
    EH_CLEAR r15
    mov      eax, 5
    ret
CdNwMismatchException:
    xor eax, eax
    ret

HvErrataCr01 ENDP

;
; Calculate a mask of all CR4 bits that are conditionally supported through CPUID.
; Input:
;  RAX = Main leaf index.
;  RCX = Sub-leaf index.
;  RBX = Table start.
;  RDX = Table entry count.
; Output:
;  RAX = CR4 mask of supported features advertised through the input CPUID leaf.
;

HvErrataPopulateCr4BitsfromTable PROC

; Back up all registers clobbered by this function.

    push rsi
    push rdi
    push r8
    push r9
    push r10

; Read the information of the input CPUID leaf/sub-leaf, and begin the accumulation loop.

    mov r9, rbx
    mov r10, rdx
    cpuid
    sub rsp, 16
    mov dword ptr [rsp+0], eax
    mov dword ptr [rsp+4], ebx
    mov dword ptr [rsp+8], ecx
    mov dword ptr [rsp+12], edx
    xor esi, esi
    xor edi, edi
LoopPopulateCr4BitsFromLeaf:

; Calculate the address of the current table entry.

    lea rax, [r9+rsi*4]

; Calculate the CR4 bitmask for the current table entry (ebx).
; Table entry byte 0 is the CR4 bit index.

    mov cl, byte ptr [rax+0]
    xor ebx, ebx
    inc ebx
    shl ebx, cl

; Read the CPUID register value (0=EAX, 1=EBX, 2=ECX, 3=EDX) for the current table entry (r8).
; Table entry byte 1 is the CPUID register index.

    mov   cl, byte ptr [rax+1]
    movzx ecx, cl
    mov   r8d, dword ptr [rsp+rcx*4]

; Determine if the table entry CPUID bit is supported.
; Produces a mask of all bits set if the bit is supported, or 0 if the bit is not supported.
; Outputs the support mask to r8.

    mov cl, byte ptr [rax+2]
    shr r8, cl
    and r8, 1
    not r8
    inc r8

; Accumulate supported features to the supported CR4 bit accumulator (rdi).
    
    and rbx, r8
    or  rdi, rbx

; Move on to the next table entry.
    
    inc esi
    cmp esi, r10d
    jnz LoopPopulateCr4BitsFromLeaf

; All table entries have been processed, return accumulated CR4 support mask.

    add rsp, 16
    mov rax, rdi
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    ret

HvErrataPopulateCr4BitsfromTable ENDP

;
; Calculate a mask of all known supported CR4 bits.
; Output:
;  RAX = CR4 support bitmask.
;

HvErrataCr4SupportMask PROC

; Backup all registers clobbered by this function.

   push rcx
   push rbx
   push rdx
   push rsi

; Accumulator of all discovered supported CR4 feature bits.
; Default to base features that are not advertised and should always be supported (0:8).

    mov esi, 1ffh

; Accumulate the mask of all CR4 bits with support advertised through CPUID_EAX_01.

    xor  eax, eax
    inc  eax
    xor  ecx, ecx
    lea  rbx, [CpuidEax01ToCr4BitTable]
    mov  edx, CPUID_EAX_01_TO_CR4_BIT_COUNT
    call HvErrataPopulateCr4BitsfromTable
    or   rsi, rax

; Accumulate the mask of all CR4 bits with support advertised through CPUID_EAX_07.

    mov  eax, 7
    xor  ecx, ecx
    lea  rbx, [CpuidEax07ToCr4BitTable]
    mov  edx, CPUID_EAX_07_TO_CR4_BIT_COUNT
    call HvErrataPopulateCr4BitsfromTable
    or   rsi, rax

; Accumulate the mask of all CR4 bits with support advertised through CPUID_EAX_07_ECX_01.

    mov  eax, 7
    xor  ecx, ecx
    inc  ecx
    lea  rbx, [CpuidEax07Ecx01ToCr4BitTable]
    mov  edx, CPUID_EAX_07_ECX_01_TO_CR4_BIT_COUNT
    call HvErrataPopulateCr4BitsfromTable
    or   rsi, rax

; Check manually for KeyLocker support for CR4.KLE.

    mov eax, 19h
    xor ecx, ecx
    cpuid
    and ebx, 1
    not rbx
    inc rbx
    and rbx, 80000h
    or  rsi, rbx

; Return the accumulated mask of all known supported CR4 bits.

    mov rax, rsi
    pop rsi
    pop rdx
    pop rbx
    pop rcx
    ret

HvErrataCr4SupportMask ENDP

;
; Test CR4 reserved bit handling.
; r15 = HV_ERRATA_CONTEXT*
;

HvErrataCr02 PROC

; Attempt to set all reserved CR4 bits one by one.
   
    call     HvErrataCr4SupportMask
    mov      rsi, rax
    not      rsi
    mov      ebx, 0
TestBitLoop:
    mov      cl, bl
    mov      eax, 1
    shl      rax, cl
    test     rsi, rax
    jz       TestBitLoopSkip
    lea      r8, [TestBitLoopSkip]
    EH_SET   r15, r8
    mov      rdx, cr4
    or       rdx, rax
    mov      cr4, rdx
    EH_CLEAR r15
    mov      [r15 + HV_ERRATA_CONTEXT.ScratchResult0], rbx
    mov      [r15 + HV_ERRATA_CONTEXT.ScratchResult1], rax
    mov      [r15 + HV_ERRATA_CONTEXT.ScratchResult2], rdx
    mov      [r15 + HV_ERRATA_CONTEXT.ScratchResult3], rsi
    xor      eax, eax
    inc      eax
    ret
TestBitLoopSkip:
    inc      ebx
    cmp      ebx, 64
    jnz      TestBitLoop
TestBitLoopEnd:
    xor      eax, eax
    ret    

HvErrataCr02 ENDP

;
; Test CR3 reserved semantics and PCID interactions.
;

HvErrataCr03 PROC

; Disable PCID usage and attempt to set a CR3 value with bit 63 set.
; This should always trigger a #GP(0), some VMMs will just ignore the bit even though PCID is disabled.

    mov      rcx, cr4
    mov      rax, 0FFFFFFFFFFFDFFFFh
    and      rcx, rax
    mov      cr4, rcx
    mov      rcx, cr3
    mov      rax, 8000000000000000h
    or       rcx, rax
    lea      rdx, [PcidOffReservedException]
    EH_SET   r15, rdx
    mov      cr3, rcx
    EH_CLEAR r15
    xor      eax, eax
    inc      eax
    ret
PcidOffReservedException:

; Test if PCID is supported.

    xor  eax, eax
    xor  ecx, ecx
    inc  eax
    cpuid
    test ecx, 20000h
    jz NoPcidSupport

; Re-enable PCID.

    mov rax, cr4
    or  rax, 20000h
    mov cr4, rax

; Attempt to switch to a PCID and see if the PCID is reflected to the actual guest CR3 value.

    mov r10, cr3
    mov rax, r10
    or  rax, 4
    mov cr3, rax
    mov rcx, cr3
    cmp rcx, rax
    mov cr3, r10
    jz  PcidReflected
    xor eax, eax
    inc eax
    inc eax
    ret
PcidReflected:
NoPcidSupport:
    xor eax, eax
    ret

HvErrataCr03 ENDP

END