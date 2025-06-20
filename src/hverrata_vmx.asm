.CODE

include hverrata_common.inc

;
; Test VMX support and CR4.VMXE mutability.
; r15 = HV_ERRATA_CONTEXT*
;

HvErrataVmx01 PROC

; Check for VMX support, test CPUID.1:ECX.VMX [bit 5].

    xor eax, eax
    xor ecx, ecx
    inc eax
    cpuid
    test ecx, 20h
    jnz HasVmxSupport

; The caller is not advertising VMX support, test if we can still modify the CR4.VMXE bit
; On AMD this should trigger a #GP(0), on intel it should be freely modifiable even if the feature is disabled.

    lea      rax, [HasNoVmxSupport]
    EH_SET   r15, rax
    mov      rdx, cr4
    or       rdx, 2000h
    mov      cr4, rdx
    EH_CLEAR r15
HasNoVmxSupport:
    ret

HasVmxSupport:

; CR4.VMXE should be freely mutable even if VMX is disabled, it just has no effect.
; Should result in (r8 == r9) and (r10 == r11), meaning our writes were properly reflected.
; Access should never cause an exception here.

    lea      rax, [SetVmxeException0]
    EH_SET   r15, rax
    mov      rdx, cr4
    xor      rdx, 2000h
    mov      r8, rdx
    mov      cr4, rdx
    mov      r9, cr4
    xor      rdx, 2000h
    mov      r10, rdx
    mov      cr4, rdx
    mov      r11, cr4
    EH_CLEAR r15
    jmp      NoSetVmxeException
SetVmxeException0:
    xor eax, eax
    inc eax
    inc eax
    ret
NoSetVmxeException:

; Ensure that the read-back CR4 values actually allowed us to modify the VMXE bit to our desired values.

    xor  r8, r9
    xor  r10, r11
    xor  r8, r10
    test r8, r8
    xor  eax, eax
    jz   VmxeAccessValid
    mov  eax, 4
VmxeAccessValid:
    ret

HvErrataVmx01 ENDP

;
; Test VMX instruction behaviour in regards to the feature control register.
; r15 = HV_ERRATA_CONTEXT*
;

HvErrataVmx02 PROC

; Check for VMX support, test CPUID.1:ECX.VMX [bit 5].

    xor eax, eax
    xor ecx, ecx
    inc eax
    cpuid
    test ecx, 20h
    jnz HasVmxSupport
    xor eax, eax
    ret
HasVmxSupport:

; Read IA32_FEATURE_CONTROL and check if VMX is advertised as disabled.

    mov  ecx, 3ah
    rdmsr
    test eax, 4
    jz   VmxSuccess

; Set up a temporary VMXON region in scratch page 0.

    cld
    xor eax, eax
    mov ecx, 512
    mov rdi, [r15 + HV_ERRATA_CONTEXT.ScratchPage0]
    rep stosq
    mov ecx, 480h
    rdmsr
    and eax, 7FFFFFFFh
    mov rcx, [r15 + HV_ERRATA_CONTEXT.ScratchPage0]
    mov dword ptr [rcx], eax

; If VMX is advertised as enabled, we should be able to use VMX instructions without #UD,
; try to enable CR4.VMXE execute VMXON using our region in scratch page 0.

    sub      rsp, 8
    lea      rax, [VmxInvalidException0]
    EH_SET   r15, rax
    
; Apply CR0 VMX operation fixed bits.

    mov r8, cr0
    mov rcx, 486h
    rdmsr
    shl rdx, 32
    or  r8, rax
    or  r8, rdx
    mov rcx, 487h
    rdmsr
    shl rdx, 32
    or  rax, rdx
    and r8, rax
    mov cr0, r8

; Apply CR4 vmx operation fixed bits.

    mov r8, cr4
    or  r8, 2000h
    mov rcx, 488h
    rdmsr
    shl rdx, 32
    or  r8, rax
    or  r8, rdx
    mov rcx, 489h
    rdmsr
    shl rdx, 32
    or  rax, rdx
    and r8, rax
    mov cr4, r8

; Attempt to enter initial vmx operation.

    mov      rax, [r15 + HV_ERRATA_CONTEXT.ScratchPage0Pa]
    mov      [rsp], rax
    vmxon    qword ptr [rsp]
    setc     cl
    movsx    ecx, cl
    mov      [r15 + HV_ERRATA_CONTEXT.ScratchResult2], rcx
    vmxoff
    EH_CLEAR r15
    jmp      VmxNoException
VmxInvalidException0:
    mov rax, [r15 + HV_ERRATA_CONTEXT.InterruptVector]
    mov [r15 + HV_ERRATA_CONTEXT.ScratchResult0], rax
    mov rax, [r15 + HV_ERRATA_CONTEXT.InterruptErrorCode]
    mov [r15 + HV_ERRATA_CONTEXT.ScratchResult1], rax
    add rsp, 8
    xor eax, eax
    inc eax
    ret
VmxNoException:
    add  rsp, 8
    test ecx, ecx
    jz VmxSuccess
    xor eax, eax
    inc eax
    inc eax
    ret
VmxSuccess:
    xor eax, eax
    ret

HvErrataVmx02 ENDP

END