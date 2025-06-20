# hverrata
An extensible test suite for x86 hypervisor development that tests for common implementation oversights and errata out of the box.

## Overview
The default provided interface for the test cases is designed to be ran in a UEFI boot services guest application.
All test cases execute under using an internal guest IDT that supports simple exception handling, and a paging environment with designated scratch regions and PTEs allowing test cases to easily test paging and cache related behaviour.
Processor state that may be clobbered or modified by a test case is automatically backed up and restored by the main test dispatcher function.
Each test is given access to the internal test context which allows the test to interact with the exception handling system, access scratch pages, set custom test-specific result values.

## Default Tests

1. PCID
    - **HvErrataPcid01**
      - Checks for fundamental PCID support.
      - Tests if PCID-local translations are properly preserved when switching between PCIDs.
        Uses the scratch page PTEs to populate the TLB with different cached translation for a page between two PCIDs,
        and ensures that the cached translation of the first PCID isn't invalidated when switching back and forth between the second PCID.
     - **HvErrataPcid02**
      - Test for proper support of INVPCID if support for PCID is advertised through cpuid.
      - Basic test to ensure that INVPCID doesn't trigger an exception if support is advertised through cpuid (and PCID is enabled).
      - Uses a similar strategy involving the scratch PTEs as HvErrataPcid01, but ensures that INVPCID does not invalidate cached translations of PCID's other than the one specified in the input descriptor.

3. INVD
    - **HvErrataInvd01**
      - Checks for unsafe direct usage of INVD in the host context, leading to corruption of internal host memory.
        This check specifically targets the manual backup and restore of guest state performed upon exit,
        assuming that the VMM uses #WB memory for its internal guest bookkeeping memory, we can load a set of canary values into the register backup area of the host's state for our virtual processor using a benign exit,
        ensure that they are written back to main memory using WBINVD, update our actual guest CPU registers to a second set of canary values (or simply clear them), then trigger the INVD exit. This will most likely lead
        to the registers backed up during the INVD exit being disregarded, and the canary values that were written back to main memory to be restored, clobbering our real guest register values. This is a serious security problem if detected,
        likely leading to VMCS corruption (due to the VMCS typically being required to be #WB), and possible escape to another guest.

4. XState
    - **HvErrataXState01**
       - Checks semantics of XCR0 bits that are required or are mutually inclusive in some way.
       - X87 must always be enabled in XCR0.
       - Software cannot enable the XSAVE feature set for AVX state but not for SSE state.
       - Software can enable the XSAVE feature set for MPX state only if it does so for both state components.
       - Software can enable the XSAVE feature set for AVX-512 state only if it does so for all three state components.
       - Software can enable the XSAVE feature set for AVX-512 state only if it does so for SSE/AVX as well.
       - Software can only enable TILEDATA if it does so for TILECFG as well.
    - **HvErrataXState02**
      - Check semantics of XCR0 MPX bits on processors that do not support MPX.
      - MPX is not supported pre-haswell, and also no longer supported on modern processors,
        despite this, they are not explicitly listed as reserved bits, like any other optional feature.
        This check aims to hit a case where the host CPU does not support MPX, but the VMM still
        allows a write to the MPX/bnd bits in XCR0, leading to a host exception.
    - **HvErrataXState03**
      - Check semantics of XCR0 bits that are erroneously treated as reserved due to the VMM not considering the actual host processor capabilities.
      - These checks are especially effective at hitting a common implementation error in most immature hypervisors where only the bits defined explicitly as reserved in the SDM are considered,
        instead of the actual bits that are not supported by the current host processor.
    - **HvErrataXState04**
      - Check semantics of XCR0 bits that should be treated as reserved but are not (referencing actual supported host processor capabilities).
    - **HvErrataXState05**
      - Check if the VMM lets us modify the host XCR0 in a way that would conflict with host XSAVE/XRSTOR, leading to backed up guest XState corruption.
        Tests if the VMM improperly isolates the guest XCR0 and updates the real processor XCR0 to the guest XCR0 before restoring the guest's
        backed up XSTATE using XRSTOR, allowing the guest to control which portions of the XState get restored, leading to stale/corrupted values being restored upon entry.
        
5. CRx
    - **HvErrataCr01**
      - Tests basic CR0 reserved bits and invalid bit combinations.
      - Attempting to set any reserved bits in CR0[63:32] results in a general-protection exception.
      - Attempting to set any reserved bits in CR0[31:0] is ignored.
      - If an attempt is made to clear CR0.PG while IA-32e mode is enabled, a general-protection fault is triggered.
      - If an attempt is made to set the PG flag to 1 when the PE flag is set to 0, a general-protection fault is triggered.
      - If an attempt is made to set the CD flag to 0 when the NW flag is set to 1, a general-protection fault is triggered.
    - **HvErrataCr02**
      - Tests basic CR4 reserved bit handling, as well as bits that are not guaranteed to be supported.
      - Ensures that the bits treated as reserved by the VMM reflect that of which are actually not advertised as supported by the processor,
       targetting a common mistake similar to that of the XState reserved bit checks, wherein the VMM only considers the bits defined as actually reserved in the SDM,
       and not the bits corresponding to features that are conditionally implemented and require explicit advertisement of support through CPUID to be accessed.
      - Calculates a mask of all reserved bits and bits that are not advertised as supported by the processor and tests them one-by-one.
    - **HvErrataCr03**
      - Tests basic reserved bit handling of CR3.
      - Tests reserved bit handling in regards to a PCID enabled state.
      - Attempts to switch to a new PCID and validate that the PCID is reflected to the actual guest CR3 value.
  
6. CPUID
    - **HvErrataCpuid01**
      - Checks for desynchronized CR4 bits in CPUID leaves 01H and 07H.
      - Some CPUID leaves actually reflect parts of the current architectural state, which, upon exit, will reflect that of the host.
      - The value of CR4.OSXSAVE[bit 18] should always be reflected to CPUID.01H:ECX.OSXSAVE[bit 27].
      - If PKU is supported, the value of CR4.PKE[bit 22] should always be reflected to CPUID.07H:ECX.OSPKE[bit 04].
    - **HvErrataCpuid02**
      - Checks for desynchronized XSTATE bits in CPUID leaf 0Dh.
      - Checks if changes to the guest XCR0 are properly reflected in the maximum save state area size reported by CPUID.
   
7. VMX
    - **HvErrataCpuid01**
      - Tests advertised VMX support and CR4.VMXE mutability.
      - CR4.VMXE should be freely mutable even if VMX is disabled, it just has no effect.
      - Ensures that CR4.VMXE writes are actually reflected to the read-back guest CR4 value.
    - **HvErrataCpuid01**
      - Tests VMX instruction behaviour in regards to the feature control register.
      - Ensures that we can enable and enter VMX operation using VMXON if support for VMX is enabled through the feature control register.
     
8. MSR
    - **HvErrataMsr01**
      - Ensures that access to invalid MSRs results in a general protection fault.
