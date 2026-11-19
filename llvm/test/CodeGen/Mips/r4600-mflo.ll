; RUN: llc -mtriple=mips64-linux-gnu -target-abi n32 -mcpu=r4600 < %s | FileCheck %s --check-prefix=R4600
; RUN: llc -mtriple=mips64-linux-gnu -target-abi n32 -mcpu=mips3 < %s | FileCheck %s --check-prefix=MIPS3

; The second multiply follows mflo directly. mips1-4 need two instructions
; between mflo and the next multiply or divide. The R4600 has no such hazard,
; so it gets no padding; the generic MIPS III CPU keeps it.

define i32 @mul_chain(i32 %a, i32 %b, i32 %c) {
; R4600-LABEL: mul_chain:
; R4600: mult $
; R4600-NEXT: mflo $
; R4600-NEXT: sll
; R4600-NEXT: mult $
; MIPS3-LABEL: mul_chain:
; MIPS3: mult $
; MIPS3-NEXT: mflo $
; MIPS3-NEXT: sll
; MIPS3-NEXT: nop
; MIPS3-NEXT: mult $
  %x = mul i32 %a, %b
  %y = mul i32 %x, %c
  ret i32 %y
}
