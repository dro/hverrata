.CODE

include hverrata_common.inc

;
; Check for desynchronized CR4 bits in cpuid leaves 01H and 07H.
; r15 = HV_ERRATA_CONTEXT*
;

HvErrataCpuid01 PROC

; Back up initial cr4 to be restored upon test failure/completion.

    mov r12, cr4

; The value of CR4.OSXSAVE[bit 18] should always be reflected to CPUID.01H:ECX.OSXSAVE[bit 27].
; Directly executing and passing through the results of CPUID from within root operation
; will use the host CR4.OSXSAVE.

    jmp OsxsaveTestSyncEnd
OsxsaveTestSync:
    xor ecx, ecx
    mov eax, 1
    cpuid
    mov [r15 + HV_ERRATA_CONTEXT.ScratchResult0], rcx
    mov rax, cr4
    shr ecx, 9
    and ecx, 40000h
    mov rax, cr4
    mov [r15 + HV_ERRATA_CONTEXT.ScratchResult1], rax
    and eax, 40000h
    cmp ecx, eax
    jz OsxsaveTestSyncPass
    xor eax, eax
    inc eax
    add rsp, 8
    mov cr4, r12
    inc [r15 + HV_ERRATA_CONTEXT.ScratchResult2]
OsxsaveTestSyncPass:
    ret
OsxsaveTestSyncEnd:

; Test the current OSXSAVE state.
    
    call OsxsaveTestSync

; Try flipping the OSXSAVE bit and retrying in case the guest and host initially shared the same setting.

    mov  r8, cr4
    xor  r8, 40000h
    mov  cr4, r8
    call OsxsaveTestSync

; If PKU is supported, the value of CR4.PKE[bit 22] should always be reflected to CPUID.07H:ECX.OSPKE[bit 04].
; Hardware support for PKU should be advertised through CPUID.07H:ECX.OSPKU[bit 03].
    
    xor ecx, ecx
    mov eax, 7
    cpuid
    test ecx, 8
    jz PkuUnsupported
    jmp PkeTestSyncEnd
PkeTestSync:
    xor ecx, ecx
    mov eax, 7
    cpuid
    shl ecx, 18
    and ecx, 400000h
    mov rax, cr4
    and eax, 400000h
    cmp ecx, eax
    jz PkeTestSyncPass
    xor eax, eax
    inc eax
    inc eax
    add rsp, 8
    mov cr4, r12
PkeTestSyncPass:
    ret
PkeTestSyncEnd:

; Test the current PKE state.

    call PkeTestSync

; Try flipping the PKE bit and retrying in case the guest and host initially shared the same setting.

    mov  r8, cr4
    mov  r9, r8
    xor  r9, 400000h
    mov  cr4, r9
    call PkeTestSync
PkuUnsupported:


; Success, restore the original guest CR4 value.

    mov cr4, r12
    xor eax, eax
    ret
    
HvErrataCpuid01 ENDP

;
; Check for desynchronized XSTATE bits in cpuid leaf 0Dh sub-leaves.
; TODO: Take into account IA32_XSS if supported!
; r15 = HV_ERRATA_CONTEXT*
;

HvErrataCpuid02 PROC

; Back up the original CR4 and enable CR4.OSXSAVE to use xgetbv/xsetbv.

    mov  rax, cr4
    push rax
    or   rax, 40000h
    mov  cr4, rax

; Back up the original XCR0 state.

    xor ecx, ecx
    xgetbv
    push rdx
    push rax

; Change to minimally-sized XCR0 state, everything disabled except X87 and SSE.

    xor ecx, ecx
    xor edx, edx
    mov eax, 3
    xsetbv

; Get current maximum save state size through sub-leaf 0.
; EAX=0DH, ECX=00H: EBX Bits [31:00].

    mov eax, 0dh
    xor ecx, ecx
    cpuid
    mov r8d, ebx

; Enable the AVX bit in XCR0, this should increase the maximum save state size.

    xor ecx, ecx
    xor edx, edx
    mov eax, 7
    xsetbv

; Get the new maximum save state size through sub-leaf 0.
; EAX=0DH, ECX=00H: EBX Bits [31:00].

    mov eax, 0dh
    xor ecx, ecx
    cpuid
    mov r9d, ebx

; Restore the original CR4 and XCR0 state.
    
    pop rax
    pop rdx
    xor ecx, ecx
    xsetbv
    pop rax
    mov cr4, rax

; The maximum save state size should differ between the two XCR0 values.

    mov   [r15 + HV_ERRATA_CONTEXT.ScratchResult0], r8
    mov   [r15 + HV_ERRATA_CONTEXT.ScratchResult1], r9
    cmp   r8d, r9d
    setz  al
    movsx eax, al
    ret

HvErrataCpuid02 ENDP

END