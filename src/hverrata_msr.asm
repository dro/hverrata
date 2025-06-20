.CODE

include hverrata_common.inc

;
; Access to invalid MSRs should result in #GP(0).
;

HvErrataMsr01 PROC

    xor      r9, r9
    xor      ecx, ecx
    not      rcx
    lea      rax, [Exception]
    EH_SET   r15, rax
    rdmsr
    inc      r9
    EH_CLEAR r15
Exception:
    mov rax, r9
    ret

HvErrataMsr01 ENDP

END