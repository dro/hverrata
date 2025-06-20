.CODE

include hverrata_common.inc

;
; rcx = HV_ERRATA_CONTEXT*
; rdx = test routine to execute.
;

HvErrataExecuteTest PROC
    mov    rax, cr4
    push   rax
    or     rax, 40000h
    mov    cr4, rax
    mov    rax, cr0
    push   rax
    push   r12
    push   r13
    push   r14
    push   r15
    push   rbx
    push   rbp
    push   rdi
    push   rsi
    mov    r15, rcx
    mov    r14, rdx
    xor    ecx, ecx
    xgetbv
    push   rax
    push   rdx
    mov    [r15 + HV_ERRATA_CONTEXT.ScratchResult0], 0
    mov    [r15 + HV_ERRATA_CONTEXT.ScratchResult1], 0
    mov    [r15 + HV_ERRATA_CONTEXT.ScratchResult2], 0
    mov    [r15 + HV_ERRATA_CONTEXT.ScratchResult3], 0
    lea    rax, [UnhandledException]
    mov    [r15 + HV_ERRATA_CONTEXT.EhHandlerDefault], rax
    mov    [r15 + HV_ERRATA_CONTEXT.EhHandlerDefaultRsp], rsp
    mov    qword ptr [r15 + HV_ERRATA_CONTEXT.InterruptAbort], 0
    call   r14
    jmp    NoUnhandledException
UnhandledException:
    mov    rsp, [r15 + HV_ERRATA_CONTEXT.EhHandlerDefaultRsp]
    xor    eax, eax
    not    eax
    mov    qword ptr [r15 + HV_ERRATA_CONTEXT.InterruptAbort], 1
NoUnhandledException:
    mov  r8, rax
    pop  rdx
    pop  rax
    xor  ecx, ecx
    xsetbv
    mov  rax, r8
    pop  rsi
    pop  rdi
    pop  rbp
    pop  rbx
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    push rax
    mov  rax, [rsp+8]
    mov  cr0, rax
    mov  rax, [rsp+16]
    mov  cr4, rax
    pop  rax
    add  rsp, 16
    ret
HvErrataExecuteTest ENDP

END