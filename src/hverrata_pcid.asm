.CODE

include hverrata_common.inc

;
; Check for fundamental PCID handling errata.
; rcx/r15 = HV_ERRATA_CONTEXT*
;

HvErrataPcid01 PROC

; Check if PCID is supported by the CPU.
; Leaf 01H, ECX bit 17: Process-context identifiers.
; A value of 1 indicates that the processor supports PCIDs and software may set CR4.PCIDE to 1.

    xor ecx, ecx
    xor eax, eax
    inc eax
    cpuid
    test ecx, 20000h

; Check if PCID isn't supported, but CR4.PCIDE is mutable.
; This is the only check we can perform if PCID isn't actually supported.
; EAX = 1 if PCIDE was erroneously mutable.

    jnz      MutablePcidCheckEnd
    mov      rdx, cr4
    or       rdx, 20000h
    lea      r10, [ExceptionSetPcid]
    EH_SET   r15, r10
    xor      eax, eax
    mov      cr4, rdx
    inc      eax
    EH_CLEAR r15
ExceptionSetPcid:
    ret
MutablePcidCheckEnd:

; Set up the scratch pages with two different values,
; this will be used to check if cached translations have been flushed.

    mov rax,             [r15 + HV_ERRATA_CONTEXT.ScratchPage0]
    mov qword ptr [rax], 24D6734h
    mov rax,             [r15 + HV_ERRATA_CONTEXT.ScratchPage1]
    mov qword ptr [rax], 5465530h
    wbinvd

; Enable PCID (if it isn't already enabled).
    
    mov rax, cr4
    or  rax, 20000h
    mov cr4, rax

; Back up the original CR3/PCID context, and switch to a new internal PCID 1,
; invalidating any possible existing translations for PCID 1.
; The PCID tag is contained by the lower 12 bits of the CR3 value.
; Pushes the original CR3 value to the stack.

    mov  rcx, cr3
    push rcx
    mov  rax, 0FFFFFFFFFFFFF000h
    and  rcx, rax
    or   rcx, 1
    mov  cr3, rcx

; Load the original ScratchPage0 properties to the TLB for PCID 1.

    mov rcx, [r15 + HV_ERRATA_CONTEXT.ScratchPage0]
    mov qword ptr [rcx], 24D6734h

; Modify the ScratchPage0 PTE to point to ScratchPage1 without flushing cached translations.
; This will result in the processor still accessing the original ScratchPage0 page in the current PCID context.
; Bits 47:12 of the PTE contain the naturally aligned physical address of the backing memory.
; This code is all designed to run with an identity mapped paging setup, so the VA is used interchangeably with the PA here.
; Pushes the original value of SearchPage0Pte to the stack.

    mov  rcx, [r15 + HV_ERRATA_CONTEXT.ScratchPage0Pte]
    mov  rcx, [rcx]
    push rcx
    mov  rax, 0FFFF000000000FFFh
    and  rcx, rax
    mov  rdx, [r15 + HV_ERRATA_CONTEXT.ScratchPage1Pa]
    mov  rax, 0FFFFFFFFFFFFF000h
    and  rdx, rax
    or   rdx, rcx
    mov  rcx, [r15 + HV_ERRATA_CONTEXT.ScratchPage0Pte]
    mov  [rcx], rdx

; ScratchPage0 is now pointing to ScratchPage1, but the current PCID should have the original translation still cached.

    mov rcx, [r15 + HV_ERRATA_CONTEXT.ScratchPage0]
    mov r8,  [rcx]
    mfence

; Switch to new internal PCID 2.
; Changing to PCID 2 shouldn't invalidate cached translations tagged with PCID 1.

    mov rcx, cr3
    mov rax, 0FFFFFFFFFFFFF000h
    and rcx, rax
    or  rcx, 2
    mov cr3, rcx
    
; Access ScratchPage0 from the context of PCID 2, should point to ScratchPage1 in PCID 2.

    mov r9, [r15 + HV_ERRATA_CONTEXT.ScratchPage0]
    mov r9, [r9]

; Switch back to PCID 1 without flushing any previous cached translations tagged with PCID 1.
; The 63rd bit in CR3 being set will cause previous cached translations for the PCID to not be flushed.

    mov rcx, cr3
    mov rax, 0FFFFFFFFFFFFF000h
    and rcx, rax
    mov rax, 8000000000000001h
    or  rcx, rax
    mov cr3, rcx

; We have switched back to PCID 1 context without flushing,
; we should still have our original cached translation for ScratchPage0 from before it was pointed to ScratchPage1.

    mov r10, [r15 + HV_ERRATA_CONTEXT.ScratchPage0]
    mov r10, [r10]

; Restore original ScratchPage0 PTE.

    pop rax
    mov rcx, [r15 + HV_ERRATA_CONTEXT.ScratchPage0Pte]
    mov [rcx], rax

; Restore original CR3 and flush translations.

    pop rax
    mov cr3, rax

; PCID flushing semantic tests complete, under normal circumstances we would expect the following results:
;  - R8  : 24D6734h (PCID 1 read from the original cached translation)
;  - R9  : 5465530h (PCID 2 read from the new flushed translation)
;  - R10 : 24D6734h (PCID 1 read from the original cached translation)

    mov [r15 + HV_ERRATA_CONTEXT.ScratchResult0], r8
    mov [r15 + HV_ERRATA_CONTEXT.ScratchResult1], r9
    mov [r15 + HV_ERRATA_CONTEXT.ScratchResult2], r10
    
    cmp   r8d,  r10d
    setnz al
    cmp   r10d, 24D6734h
    setnz cl
    add   al,  cl
    cmp   r9d, 5465530h
    setnz cl
    add   al,  cl
    movsx eax, al
    ret

HvErrataPcid01 ENDP

;
; Test for proper support of invpcid if support for PCID is advertised through cpuid.
; r15 = HV_ERRATA_CONTEXT*
;

HvErrataPcid02 PROC

; Check if PCID and invpcid is supported by the CPU.
; PCID support: Leaf 01H, ECX bit 17: Process-context identifiers.
; INVPCID support: Leaf 07H, EBX Bit 10: INVPCID.

    xor  eax, eax
    xor  ecx, ecx
    inc  eax
    cpuid
    and  ecx, 20000h
    mov  r8d, ecx
    mov  r8,  rcx
    mov  eax, 7
    xor  ecx, ecx
    cpuid
    and  ebx, 400h
    or   ebx, r8d
    test ebx, (400h or 20000h)
    jnz  PcidCheckEnd
    xor  eax, eax
    ret
PcidCheckEnd:

; Enable PCID (if it is not already enabled).
    
    mov rax, cr4
    or  rax, 20000h
    mov cr4, rax

; Test if using invpcid causes an exception despite being advertised as supported.
; Sets up a temporary invpcid descriptor inside of the first scratch page to avoid
; stack cleanup upon exception.

    lea           r10,               [ExceptionInvpcid]
    EH_SET        r15,               r10
    mov           rax,               [r15 + HV_ERRATA_CONTEXT.ScratchPage0]
    mov           qword ptr [rax],   0FFh  ; Descriptor PCID.
    mov           qword ptr [rax+8], 0h    ; Descriptor reserved/linear address.
    xor           ecx,               ecx   ; INVPCID type 0, individual address invalidation.
    invpcid       rcx,               oword ptr [rax]
    EH_CLEAR      r15
    jmp           NoExceptionInvpcid
ExceptionInvpcid:
    xor eax, eax
    inc eax
    ret
NoExceptionInvpcid:

; Setup magic canary values in each page.

    mov rcx, [r15 + HV_ERRATA_CONTEXT.ScratchPage0]
    mov qword ptr [rcx], 0A8CAA60Fh
    mov rcx, [r15 + HV_ERRATA_CONTEXT.ScratchPage1]
    mov qword ptr [rcx], 0DA5F538Ch
    wbinvd

; Back up the original CR3/PCID context, and switch to a new internal PCID 3,
; invalidating any possible existing translations for PCID 3.
; The PCID tag is contained by the lower 12 bits of the CR3 value.
; Pushes the original CR3 value to the stack.

    mov  rcx, cr3
    push rcx
    mov  rax, 0FFFFFFFFFFFFF000h
    and  rcx, rax
    or   rcx, 3
    mov  cr3, rcx

; Ensure that the ScratchPage0 properties are loaded in the TLB for the current PCID.

    mov rcx, [r15 + HV_ERRATA_CONTEXT.ScratchPage0]
    mov qword ptr [rcx], 0A8CAA60Fh

; Modify the ScratchPage0 PTE to point to ScratchPage1 without flushing cached translations.
; This will result in the processor still accessing the original ScratchPage0 page in the current PCID context.
; Bits 47:12 of the PTE contain the naturally aligned physical address of the backing memory.
; This code is all designed to run with an identity mapped paging setup, so the VA is used interchangeably with the PA here.
; Pushes the original value of SearchPage0Pte to the stack.

    mov  rcx, [r15 + HV_ERRATA_CONTEXT.ScratchPage0Pte]
    mov  rcx, [rcx]
    push rcx
    mov  rax, 0FFFF000000000FFFh
    and  rcx, rax
    mov  rdx, [r15 + HV_ERRATA_CONTEXT.ScratchPage1Pa]
    mov  rax, 0FFFFFFFFFFFFF000h
    and  rdx, rax
    or   rdx, rcx
    mov  rcx, [r15 + HV_ERRATA_CONTEXT.ScratchPage0Pte]
    mov  [rcx], rdx

; Invalidate all cached translations for PCID 2 (we are currently using PCID 1).

    sub     rsp, 16
    mov     qword ptr [rsp], 4h    ; Descriptor PCID.
    mov     qword ptr [rsp+8], 4h  ; Descriptor reserved/linear address.
    mov     eax, 1                 ; INVPCID type 1: single-context invalidation.
    invpcid rax, oword ptr [rsp]
    add     rsp, 16

; Read back the initial ScratchPage0 canary value, if no cached translations
; were invalidated for PCID 1, then we should still get back the first canary,
; and not the second one.

    mov r8, [r15 + HV_ERRATA_CONTEXT.ScratchPage0]
    mov r8, [r8]
    cmp r8d, 0A8CAA60Fh
    mfence

; Restore the backed up original ScratchPage0 PTE value and CR3.

    pop rax
    mov rcx, [r15 + HV_ERRATA_CONTEXT.ScratchPage0Pte]
    mov [rcx], rax
    pop rax
    mov cr3, rax

; Invalidating the cached translations of a different PCID should never affect our own,
; ensure that we have still gotten back the first canary from our original cached translation.

    setnz al
    movsx eax, al
    ret

HvErrataPcid02 ENDP

END