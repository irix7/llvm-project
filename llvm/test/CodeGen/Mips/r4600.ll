; RUN: llc -mtriple=mips64-linux-gnu -target-abi n32 -mcpu=r4600 < %s | FileCheck %s

; The R4600 is MIPS III: 64-bit integer ops and the FPU are available, and
; MIPS32 only instructions are not used.

define i32 @mul32(i32 %a, i32 %b) {
; CHECK-LABEL: mul32:
; CHECK: mult $
; CHECK: mflo $
  %r = mul i32 %a, %b
  ret i32 %r
}

define float @fadd32(float %a, float %b) {
; CHECK-LABEL: fadd32:
; CHECK: add.s $f0, $f12, $f13
  %r = fadd float %a, %b
  ret float %r
}
