HV_ERRATA_CONTEXT STRUCT
    ScratchPage0        dq ?
    ScratchPage1        dq ?
    ScratchPage0Pte     dq ?
    ScratchPage1Pte     dq ?
    ScratchPage0Pa      dq ?
    ScratchPage1Pa      dq ?
    EhHandler           dq ?
    EhHandlerDefault    dq ?
    EhHandlerDefaultRsp dq ?
    ScratchResult0      dq ?
    ScratchResult1      dq ?
    ScratchResult2      dq ?
    ScratchResult3      dq ?
    InterruptVector	    dq ?
	InterruptErrorCode  dq ?
	InterruptAbort      dq ?
	InterruptRip        dq ?
HV_ERRATA_CONTEXT ENDS

EH_SET MACRO ctx, value
    mov qword ptr [ctx + HV_ERRATA_CONTEXT.EhHandler], value
endm

EH_CLEAR MACRO ctx
    mov qword ptr [ctx + HV_ERRATA_CONTEXT.EhHandler], 0
endm