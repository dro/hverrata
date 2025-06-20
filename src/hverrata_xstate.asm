.CODE

include hverrata_common.inc

;
; Check semantics of XCR0 bits that are required or are mutually inclusive in some way.
; r15 = HV_ERRATA_CONTEXT*
;

HvErrataXState01 PROC

; Enable guest CR4.OSXSAVE to use xgetbv/xsetbv.

    mov  rax, cr4
    or   rax, 40000h
    mov  cr4, rax

; Count of exceptions triggered that were not #GP.

    xor r10, r10

; X87 must always be enabled in XCR0.

    lea      rax, [ExceptionX87]
    EH_SET   r15, rax
    xor      ecx, ecx
    xor      eax, eax
    xor      edx, edx
    xsetbv
    EH_CLEAR r15
    xor      eax, eax
    inc      eax
    ret
ExceptionX87:
    mov   rax, [r15 + HV_ERRATA_CONTEXT.InterruptVector]
    cmp   rax, 0dh
    setnz cl
    movzx ecx, cl
    add   r10, rcx

; Software cannot enable the XSAVE feature set for AVX state but not for SSE state.

    lea      rax, [ExceptionAvxNoSse]
    EH_SET   r15, rax
    xor      ecx, ecx
    xor      edx, edx
    mov      eax, 5
    xsetbv
    EH_CLEAR r15
    xor      eax, eax
    inc      eax
    inc      eax
    ret
ExceptionAvxNoSse:
    mov   rax, [r15 + HV_ERRATA_CONTEXT.InterruptVector]
    cmp   rax, 0dh
    setnz cl
    movzx ecx, cl
    add   r10, rcx

; Software can enable the XSAVE feature set for MPX state only if it does so for both state components.

    lea      rax, [ExceptionMpx]
    EH_SET   r15, rax
    xor      ecx, ecx
    xor      edx, edx
    mov      eax, 0bh
    xsetbv
    EH_CLEAR r15
    xor      eax, eax
    inc      eax
    inc      eax
    ret
ExceptionMpx:
    mov   rax, [r15 + HV_ERRATA_CONTEXT.InterruptVector]
    cmp   rax, 0dh
    setnz cl
    movzx ecx, cl
    add   r10, rcx

; Software can enable the XSAVE feature set for AVX-512 state only if it does so for all three state components.

    lea      rax, [ExceptionAvx1]
    EH_SET   r15, rax
    xor      ecx, ecx
    xor      edx, edx
    mov      eax, 0c7h
    xsetbv
    EH_CLEAR r15
    xor      eax, eax
    inc      eax
    inc      eax
    ret
ExceptionAvx1:
    mov   rax, [r15 + HV_ERRATA_CONTEXT.InterruptVector]
    cmp   rax, 0dh
    setnz cl
    movzx ecx, cl
    add   r10, rcx

; Software can enable the XSAVE feature set for AVX-512 state only if it does so for SSE/AVX as well.

    lea      rax, [ExceptionAvx2]
    EH_SET   r15, rax
    xor      ecx, ecx
    xor      edx, edx
    mov      eax, 0e3h
    xsetbv
    EH_CLEAR r15
    mov eax, 3
    ret
ExceptionAvx2:
    mov   rax, [r15 + HV_ERRATA_CONTEXT.InterruptVector]
    cmp   rax, 0dh
    setnz cl
    movzx ecx, cl
    add   r10, rcx

; Software can only enable TILEDATA if it does so for TILECFG as well.

    lea      rax, [ExceptionAmx]
    EH_SET   r15, rax
    xor      ecx, ecx
    xor      edx, edx
    mov      eax, 20003h
    xsetbv
    EH_CLEAR r15
    mov eax, 4
    ret
ExceptionAmx:
    mov   rax, [r15 + HV_ERRATA_CONTEXT.InterruptVector]
    mov   [r15 + HV_ERRATA_CONTEXT.ScratchResult1], rax
    cmp   rax, 0dh
    setnz cl
    movzx ecx, cl
    add   r10, rcx

; We should only have ever received #GP exceptions.

    mov  [r15 + HV_ERRATA_CONTEXT.ScratchResult1], r10
    test r10, r10
    jz Success
    mov eax, 5
    ret
Success:
    xor eax, eax
    ret

HvErrataXState01 ENDP

;
; Check semantics of XCR0 MPX bits on processors that do not support MPX.
; r15 = HV_ERRATA_CONTEXT*
;

HvErrataXState02 PROC

; Enable guest CR4.OSXSAVE to use xgetbv/xsetbv.

    mov  rax, cr4
    or   rax, 40000h
    mov  cr4, rax

; MPX is not supported pre-haswell, and also no longer supported on modern processors,
; despite this, they are not explicitly listed as reserved bits, like any other optional feature.
; This check aims to hit a case where the host CPU does not support MPX, but the VMM still
; allows a write to the MPX/bnd bits in XCR0, leading to a host exception.
; This is explicitly checked here as it requires both XCR0 bits to be set to function.

    mov      eax, 7
    xor      ecx, ecx
    cpuid
    mov      [r15 + HV_ERRATA_CONTEXT.ScratchResult0], rbx
    test     ebx, 4000h
    jnz      MpxSupported
    mov      qword ptr [r15 + HV_ERRATA_CONTEXT.ScratchResult1], 1
    lea      rax, [MpxException]
    EH_SET   r15, rax
    xor      edx, edx
    mov      eax, 1bh
    xor      ecx, ecx
    xsetbv
    EH_CLEAR r15
    xor      eax, eax
    inc      eax
    ret
MpxException:
MpxSupported:
    xor eax, eax
    ret

HvErrataXState02 ENDP

;
; Check semantics of XCR0 bits that are erroneously treated as reserved due to
; the VMM not considering the actual host processor capabilities.
; r15 = HV_ERRATA_CONTEXT*
;

HvErrataXState03 PROC

; Enable guest CR4.OSXSAVE to use xgetbv/xsetbv.

    mov  rax, cr4
    or   rax, 40000h
    mov  cr4, rax

; Query supported XCR0 bits and attempt to set XCR0 to all supported bits.
; Leaf 0DH main leaf (ECX = 0).
; EAX Bits 31-00: Reports the supported bits of the lower 32 bits of XCR0.
; EDX Bits 31-00: Reports the supported bits of the upper 32 bits of XCR0.

    mov      eax, 0dh
    xor      ecx, ecx
    cpuid
    mov      [r15 + HV_ERRATA_CONTEXT.ScratchResult0], rax
    mov      [r15 + HV_ERRATA_CONTEXT.ScratchResult1], rdx
    lea      rcx, [Exception]
    EH_SET   r15, rcx
    xor      r8, r8
    xor      ecx, ecx
    xsetbv
    EH_CLEAR r15
    jmp NoException
Exception:
    inc r8d
NoException:
    mov eax, r8d
    ret

HvErrataXState03 ENDP

;
; Check semantics of XCR0 bits that should be treated as reserved but are not.
; r15 = HV_ERRATA_CONTEXT*
;

HvErrataXState04 PROC

; Enable guest CR4.OSXSAVE to use xgetbv/xsetbv.

    mov  rax, cr4
    or   rax, 40000h
    mov  cr4, rax

; Query supported XCR0 bits.
; Leaf 0DH main leaf (ECX = 0).
; EAX Bits 31-00: Reports the supported bits of the lower 32 bits of XCR0.
; EDX Bits 31-00: Reports the supported bits of the upper 32 bits of XCR0.

    mov      eax, 0dh
    xor      ecx, ecx
    cpuid

; Test individually setting each reserved bit one by one.

    shl      rdx, 32
    mov      rsi, rax
    or       rsi, rdx
    not      rsi
    mov      ebx, 0
TestBitLoop:
    mov      cl, bl
    mov      eax, 1
    shl      rax, cl
    test     rsi, rax
    jz       TestBitLoopSkip
    mov      rdx, rax
    shr      rdx, 32
    or       rax, 3
    mov      eax, eax
    lea      r8, [TestBitLoopSkip]
    EH_SET   r15, r8
    xor      ecx, ecx
    xsetbv
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

HvErrataXState04 ENDP

;
; Check if the VMM lets us modify the host XCR0 in a way that would conflict with host XSAVE/XRSTOR.
; r15 = HV_ERRATA_CONTEXT*
;

HvErrataXState05 PROC

; Enable guest CR4.OSXSAVE to use xgetbv/xsetbv.

    mov  rax, cr4
    or   rax, 40000h
    mov  cr4, rax

; Set up a canary value in an SSE register, disable SSE state saving and trigger a VMEXIT.
; If the VMM has not properly isolated the guest XCR0, this should cause the host to not
; backup/restore any SSE state if they are using XSAVE/XRSTOR upon context switches.
;
; set first canary value in SSE non-volatile register.
; xsetbv(1) will backup SSE state normally upon exit, but not restore it upon entry.
; overwrite first canary value with second canary value.
; xsetbv(3) will not backup any SSE state upon exit, re-enable SSE xsave/xrstor,
; then overwrite the current registers with the stale backup from the first xsetbv call.

    sub    rsp, 16
    mov    qword ptr [rsp], 0AC676BE3h
    mov    qword ptr [rsp+8], 0
    movdqa xmm1, xmm7
    add    rsp, 16
    movdqu xmm7, [rsp]
    mov    eax, 1
    xor    edx, edx
    xor    ecx, ecx
    xsetbv
    xorps  xmm7, xmm7
    mov    eax, 3
    xsetbv

; If the guest XCR0 was erroneously applied to the host inbetween their exit/entry xsave/xrstor,
; the current value of xmm7 should have been restored to the original canary value.

    movd   eax, xmm7
    movdqa xmm7, xmm1
    mov    [r15 + HV_ERRATA_CONTEXT.ScratchResult0], rax
    cmp    eax, 0AC676BE3h
    setz   al
    movsx  eax, al
    ret

HvErrataXState05 ENDP

END