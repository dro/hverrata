.CODE

include hverrata_common.inc

;
; Check for unsafe usage of INVD within the host, allowing for corruption of internal VMM state.
;

HvErrataInvd01 PROC

; Set up first canary value in registers and trigger a exit to attempt to get the VMM to
; load them into cache when backing up the GPRs of the guest upon exit.
    
    mov rax, 97FC977EE0CC9B29h
    mov rbx, rax
    mov rcx, rax
    mov rdx, rax
    mov rsi, rax
    cpuid

; Ensure that any pending WB data is flushed to main memory before we test INVD.
; This should cause the host updates of the guest GPRs to be flushed to main memory.

    wbinvd

; Set up the second set of canary values in registers and trigger INVD.
; The INVD should disregard the current set of backed up registers,
; and leave us with the first set of canary values that were flushed to main memory.

    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    invd

; If the host has executed INVD, and they are using WB memory for their VP state,
; our latest register values should have been trashed, leaving us with the original
; set of flushed canary values from main memory.

    mov   [r15 + HV_ERRATA_CONTEXT.ScratchResult0], rsi
    mov   rax, 97FC977EE0CC9B29h
    mov   r9, rax
    xor   eax, eax
    cmp   rbx, r9
    setz  r8b
    add   al, r8b
    cmp   rcx, r9
    setz  r8b
    add   al, r8b
    cmp   rdx, r9
    setz  r8b
    add   al, r8b
    cmp   rsi, r9
    setz  r8b
    add   al, r8b
    movsx eax, al
    ret

HvErrataInvd01 ENDP

END