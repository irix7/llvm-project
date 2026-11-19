# PREF is a MIPS IV instruction. The R4600 is MIPS III and takes a Reserved
# Instruction exception on it, so the assembler must reject it for r4600.
# RUN: not llvm-mc -triple=mips64-linux-gnu -target-abi n32 -mcpu=r4600 -show-encoding < %s 2>&1 | FileCheck %s --check-prefix=R4600
# RUN: llvm-mc -triple=mips64-linux-gnu -target-abi n32 -mcpu=mips4 -show-encoding < %s | FileCheck %s --check-prefix=MIPS4

  pref 0, 0($4)

# R4600: error: instruction requires a CPU feature not currently enabled
# MIPS4: pref 0, 0($4) # encoding: [0xcc,0x80,0x00,0x00]
