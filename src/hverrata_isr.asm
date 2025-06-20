.CODE

include hverrata_common.inc

VECTOR_ERROR_CODE_MASK equ 227D00h
VECTOR_CLAMP_MASK equ 3Fh

INTERRUPT_FRAME STRUCT
    XRax      dq ?
    Vector	  dq ?
    ErrorCode dq ?
    Rip		  dq ?
    XCs		  dq ?
    RFlags	  dq ?
    XRsp      dq ?
    XSs		  dq ?
INTERRUPT_FRAME ENDS

;
; The size of interrupt-stack pushes is fixed at 64 bits; and the processor uses 8-byte, zero extended stores.
; The stack pointer (SS:RSP) is pushed unconditionally on interrupts.
; The new SS is set to NULL if there is a change in CPL.
; In IA-32e mode, the RSP is aligned to a 16-byte boundary before pushing the stack frame.
; The stack frame itself is aligned on a 16-byte boundary when the interrupt handler is called.
; The processor can arbitrarily realign the new RSP on interrupts because the previous
; (possibly unaligned) RSP is unconditionally saved on the; newly aligned stack.
; The previous RSP will be automatically restored by a subsequent IRET.
;
; Handler stack upon entry to this function:
; Note: the vector index is pushed by us, not the processor.
;
; | SS
; | RSP
; | RFLAGS
; | CS
; | RIP
; | Error Code (optional)
; | Vector Index <- Current RSP
;

HvErrataIsrHandler PROC

; Backup temporary scratch registers before use

    push rcx
    push rdx

; Read vector index from the stack.
; Skip vector indices over 63, so that large ones do not wrap around in the shift.

    mov rcx, [rsp+16]
    cmp rcx, VECTOR_CLAMP_MASK
    jge HasNoErrorCodeAbove63

; Convert the pushed vector index to bit index,
; and check if this vector pushes an error code onto the stack.

    xor edx, edx
    inc edx
    shl rdx, cl 

; Mask vector bit with error code mask, result will be non-zero if this vector pushes an error code.
; If this vector doesn't push an error code, we must push a placeholder one, and re-adjust the stack.

    and  rdx, VECTOR_ERROR_CODE_MASK
    test rdx, rdx
    pop  rdx
    pop  rcx
    jne  HasErrorCode
    jmp  HasNoErrorCode
HasNoErrorCodeAbove63:
    pop rdx
    pop rcx
HasNoErrorCode:

; If we reach this point, no error code should have been pushed,
; Push vector index again, overwrite old vector index field with dummy error code.

    push [rsp]
    mov  qword ptr [rsp+8], 0
HasErrorCode:

; Back up temporary registers used internally in the handler.

    push rax

; Disregard any NMIs received during the test cases.
    
    mov rax, [rsp + INTERRUPT_FRAME.Vector]
    cmp eax, 2
    jz  SkipInterrupt

; Store the interrupt information to the test context.

    mov rax, [rsp + INTERRUPT_FRAME.Vector]
    mov [r15 + HV_ERRATA_CONTEXT.InterruptVector], rax
    mov rax, [rsp + INTERRUPT_FRAME.ErrorCode]
    mov [r15 + HV_ERRATA_CONTEXT.InterruptErrorCode], rax
    mov rax, [rsp + INTERRUPT_FRAME.Rip]
    mov [r15 + HV_ERRATA_CONTEXT.InterruptRip], rax

; Set up the interrupt frame to return back to the user-defined exception handler address.
; If no handler is currently set, return to the default handler to perform an unexexpected
; interrupt abort of the current test case.

    mov  rax, [r15 + HV_ERRATA_CONTEXT.EhHandler]
    test rax, rax
    jnz  HandlerSet
    mov  rax, [r15 + HV_ERRATA_CONTEXT.EhHandlerDefault]
HandlerSet:
    mov [rsp + INTERRUPT_FRAME.Rip], rax

; The current exception handler routine is cleared automatically if triggered.

    xor rax, rax
    mov [r15 + HV_ERRATA_CONTEXT.EhHandler], rax

; Restore temporary registers used internally in the handler, and Return from the interrupt.
; RSP must be pointing to the RIP value in the interrupt frame.

SkipInterrupt:
    pop rax
    add rsp, 16
    iretq

HvErrataIsrHandler ENDP

;
; ISR handler helper entries that push their corresponding vector numbers to the stack for the real ISR handler.
;

HvErrataIsrTrampoline0:
    jmp HvErrataIsrHandler
HvErrataIsrDispatch0::
    push 0
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch1::
    push 1
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch2::
    push 2
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch3::
    push 3
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch4::
    push 4
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch5::
    push 5
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch6::
    push 6
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch7::
    push 7
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch8::
    push 8
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch9::
    push 9
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch10::
    push 10
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch11::
    push 11
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch12::
    push 12
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch13::
    push 13
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch14::
    push 14
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch15::
    push 15
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch16::
    push 16
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch17::
    push 17
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch18::
    push 18
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch19::
    push 19
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch20::
    push 20
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch21::
    push 21
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch22::
    push 22
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch23::
    push 23
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch24::
    push 24
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch25::
    push 25
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch26::
    push 26
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch27::
    push 27
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch28::
    push 28
    jmp short HvErrataIsrTrampoline0
HvErrataIsrDispatch29::
    push 29
    jmp short HvErrataIsrTrampoline0
HvErrataIsrTrampoline1:
    jmp HvErrataIsrTrampoline0
HvErrataIsrDispatch30::
    push 30
    jmp short HvErrataIsrTrampoline1
HvErrataIsrDispatch31::
    push 31
    jmp short HvErrataIsrTrampoline1

PUBLIC HvErrataIsrDispatch0
PUBLIC HvErrataIsrDispatch1
PUBLIC HvErrataIsrDispatch2
PUBLIC HvErrataIsrDispatch3
PUBLIC HvErrataIsrDispatch4
PUBLIC HvErrataIsrDispatch5
PUBLIC HvErrataIsrDispatch6
PUBLIC HvErrataIsrDispatch7
PUBLIC HvErrataIsrDispatch8
PUBLIC HvErrataIsrDispatch9
PUBLIC HvErrataIsrDispatch10
PUBLIC HvErrataIsrDispatch11
PUBLIC HvErrataIsrDispatch12
PUBLIC HvErrataIsrDispatch13
PUBLIC HvErrataIsrDispatch14
PUBLIC HvErrataIsrDispatch15
PUBLIC HvErrataIsrDispatch16
PUBLIC HvErrataIsrDispatch17
PUBLIC HvErrataIsrDispatch18
PUBLIC HvErrataIsrDispatch19
PUBLIC HvErrataIsrDispatch20
PUBLIC HvErrataIsrDispatch21
PUBLIC HvErrataIsrDispatch22
PUBLIC HvErrataIsrDispatch23
PUBLIC HvErrataIsrDispatch24
PUBLIC HvErrataIsrDispatch25
PUBLIC HvErrataIsrDispatch26
PUBLIC HvErrataIsrDispatch27
PUBLIC HvErrataIsrDispatch28
PUBLIC HvErrataIsrDispatch29
PUBLIC HvErrataIsrDispatch30
PUBLIC HvErrataIsrDispatch31

END