.CODE

include hverrata_common.inc

;
; Read the current CS segment selector.
;

HvErrataArchReadCsSelector PROC
    mov ax, cs
    ret
HvErrataArchReadCsSelector ENDP

END