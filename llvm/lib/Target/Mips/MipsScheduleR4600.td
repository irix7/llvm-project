//===- MipsScheduleR4600.td - R4600 Scheduling --*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Scheduling model for the IDT R4600 (and R4600SC, the variant with a
// secondary cache). The secondary cache is outside the CPU core and does
// not change instruction timing as seen by the compiler, so one model
// covers both.
//
// Latencies come from the IDT R4600/R4700 Hardware User's Manual, Rev 2.0:
// Table 1.19 (floating-point latencies), Table 1.23 (pipeline comparison)
// and Table 2.2 (multiply and divide). Instructions that the manual does not
// time are marked "assumed" below and must be measured before anyone relies
// on them.
//
// The R4600 is single issue and in order, with a 2-cycle load latency and no
// penalty for taken branches. Integer multiply runs in the floating-point
// multiplier, and integer divide runs in the floating-point adder.
//
// CompleteModel = 1 makes TableGen reject any MIPS III or FPU instruction
// that has no entry in an InstRW list below and is not in
// UnsupportedFeatures.

def MipsR4600Model : SchedMachineModel {
  int IssueWidth = 1;
  int MicroOpBufferSize = 0; // In order.
  int LoadLatency = 2;       // Table 1.23.
  int MispredictPenalty = 0; // Table 1.23: no penalty for taken branches.

  let CompleteModel = 1;
  let FullInstRWOverlapCheck = 1;

  // Predicates for ISA levels and ASEs that the R4600 does not implement.
  // MIPS III and the FPU instructions it does implement stay supported.
  list<Predicate> UnsupportedFeatures = [HasMips4_32, HasMips4_32r2,
                                         HasMips5_32r2, HasMips32, HasMips32r2,
                                         HasMips32r5, HasMips32r6, HasMips64,
                                         HasMips64r2, HasMips64r5, HasMips64r6,
                                         HasMadd4, HasVirt,
                                         HasGINV, HasEVA, HasMSA, HasDSP,
                                         HasDSPR2, HasDSPR3, HasMT, HasCRC,
                                         HasCnMips, HasCnMipsP, HasMips3D,
                                         IsR5900, InMicroMips,
                                         InMips16Mode];
}

let SchedModel = MipsR4600Model in {

// Integer pipeline, load/store unit and the shared floating-point units.
def R4600Int : ProcResource<1>;
def R4600LSU : ProcResource<1>;
// Integer multiply and the floating-point multiplier are the same unit.
def R4600FPMul : ProcResource<1>;
// Integer divide shares the floating-point add, convert and divide unit.
def R4600FPAdd : ProcResource<1>;

// Integer ALU and shift operations.
def R4600WriteALU : SchedWriteRes<[R4600Int]> {
  let Latency = 1;
}

// Integer loads.
def R4600WriteLoad : SchedWriteRes<[R4600LSU]> {
  let Latency = 2;
}

// Integer stores.
def R4600WriteStore : SchedWriteRes<[R4600LSU]> {
  let Latency = 1;
}

// Branches and jumps.
def R4600WriteBranch : SchedWriteRes<[R4600Int]> {
  let Latency = 2;
}

// MULT and MULTU: the FP multiplier is busy for the 4-cycle issue.
def R4600WriteMULT : SchedWriteRes<[R4600FPMul]> {
  let Latency = 10;
  let ReleaseAtCycles = [4];
}

// DMULT and DMULTU: the FP multiplier is busy for the 4-cycle issue.
def R4600WriteDMULT : SchedWriteRes<[R4600FPMul]> {
  let Latency = 12;
  let ReleaseAtCycles = [4];
}

// SDIV and UDIV: the FP adder is busy for the 4-cycle issue.
def R4600WriteDIV : SchedWriteRes<[R4600FPAdd]> {
  let Latency = 42;
  let ReleaseAtCycles = [4];
}

// DSDIV and DUDIV: the FP adder is busy for the 4-cycle issue.
def R4600WriteDDIV : SchedWriteRes<[R4600FPAdd]> {
  let Latency = 74;
  let ReleaseAtCycles = [4];
}

// MFHI and MFLO are 2 cycles. MTHI and MTLO are assumed to match.
def R4600WriteHILO : SchedWriteRes<[R4600Int]> {
  let Latency = 2;
}

// Floating-point add and subtract.
def R4600WriteFPAdd : SchedWriteRes<[R4600FPAdd]> {
  let Latency = 4;
}

// Floating-point compare.
def R4600WriteFPCmp : SchedWriteRes<[R4600FPAdd]> {
  let Latency = 3;
}

// Floating-point multiply: the multiplier takes a new operand every 6 cycles.
def R4600WriteFPMul : SchedWriteRes<[R4600FPMul]> {
  let Latency = 8;
  let ReleaseAtCycles = [6];
}

// Single-precision divide. The repeat rate is assumed equal to the latency.
def R4600WriteFPDivS : SchedWriteRes<[R4600FPAdd]> {
  let Latency = 32;
  let ReleaseAtCycles = [32];
}

// Double-precision divide. The repeat rate is assumed equal to the latency.
def R4600WriteFPDivD : SchedWriteRes<[R4600FPAdd]> {
  let Latency = 61;
  let ReleaseAtCycles = [61];
}

// Single-precision square root. The repeat rate is assumed equal to the
// latency.
def R4600WriteFPSqrtS : SchedWriteRes<[R4600FPAdd]> {
  let Latency = 31;
  let ReleaseAtCycles = [31];
}

// Double-precision square root. The repeat rate is assumed equal to the
// latency.
def R4600WriteFPSqrtD : SchedWriteRes<[R4600FPAdd]> {
  let Latency = 60;
  let ReleaseAtCycles = [60];
}

// Floating-point absolute value, negate and move.
def R4600WriteFPMove : SchedWriteRes<[R4600Int]> {
  let Latency = 1;
}

// Floating-point to fixed-point conversions (FIX).
def R4600WriteFPToInt : SchedWriteRes<[R4600FPAdd]> {
  let Latency = 4;
}

// Fixed-point to floating-point conversions (FLOAT).
def R4600WriteIntToFP : SchedWriteRes<[R4600FPAdd]> {
  let Latency = 6;
}

// Conversions between single and double. Not in the manual, assumed as FIX.
def R4600WriteFPFormat : SchedWriteRes<[R4600FPAdd]> {
  let Latency = 4;
}

// Floating-point loads.
def R4600WriteFPLoad : SchedWriteRes<[R4600LSU]> {
  let Latency = 2;
}

// Floating-point stores.
def R4600WriteFPStore : SchedWriteRes<[R4600LSU]> {
  let Latency = 1;
}

// Moves between the integer and FP register files, and FP control moves. Not in
// the manual, assumed 2.
def R4600WriteFPXfer : SchedWriteRes<[R4600Int]> {
  let Latency = 2;
}

// CP0, cache, TLB, ERET, SYNC, WAIT, PREF and RDHWR. Not in the manual, assumed
// 1.
def R4600WriteCop0 : SchedWriteRes<[R4600Int]> {
  let Latency = 1;
}

// COP2 and COP3. The R4600 has no COP2 or COP3. Assumed 1.
def R4600WriteCop2 : SchedWriteRes<[R4600Int]> {
  let Latency = 1;
}

// Store-conditional. Not in the manual, assumed 2.
def R4600WriteLLSC : SchedWriteRes<[R4600LSU]> {
  let Latency = 2;
}

// Traps, SYSCALL and BREAK. Not in the manual, assumed 1.
def R4600WriteTrap : SchedWriteRes<[R4600Int]> {
  let Latency = 1;
}


// Assignments. Each name appears in exactly one list.
// 1 cycle ALU and shift operations (Table 1.23: ALU 1, variable shifts 1 to
// issue)
def : InstRW<[R4600WriteALU], (instrs ADD, ADDi, ADDiu, ADDu, AND, AND64, ANDi,
                                      ANDi64, COPY, DADD, DADDi, DADDiu, DADDu,
                                      DSLL, DSLL32, DSLL64_32, DSLLV, DSRA,
                                      DSRA32, DSRAV, DSRL, DSRL32, DSRLV, DSUB,
                                      DSUBu, EHB, LUi, LUi64, NOP, NOR, NOR64,
                                      OR, OR64, ORi, ORi64, SLL, SLL64_32,
                                      SLL64_64, SLLV, SLT, SLT64, SLTi, SLTi64,
                                      SLTiu, SLTiu64, SLTu, SLTu64, SRA, SRAV,
                                      SRL, SRLV, SSNOP, SUB, SUBu, XOR, XOR64,
                                      XORi, XORi64)>;

// Loads: 2 cycles (Table 1.23)
def : InstRW<[R4600WriteLoad], (instrs LB, LB64, LBu, LBu64, LD, LDL, LDR, LH,
                                       LH64, LHu, LHu64, LL, LL64, LLD, LW,
                                       LW64, LWL, LWL64, LWR, LWR64, LWu)>;

// Stores: 1 cycle, store buffer (Table 1.23)
def : InstRW<[R4600WriteStore], (instrs SB, SB64, SD, SDL, SDR, SH, SH64, SW,
                                        SW64, SWL, SWL64, SWR, SWR64)>;

// Branches and jumps: 2 cycles, no taken-branch penalty (Table 1.23)
def : InstRW<[R4600WriteBranch], (instrs B, BAL_BR, BC1F, BC1FL, BC1T, BC1TL,
                                         BEQ, BEQ64, BEQL, BGEZ, BGEZ64, BGEZAL,
                                         BGEZALL, BGEZL, BGTZ, BGTZ64, BGTZL,
                                         BLEZ, BLEZ64, BLEZL, BLTZ, BLTZ64,
                                         BLTZAL, BLTZALL, BLTZL, BNE, BNE64,
                                         BNEL, J, JAL, JALR, JALR64,
                                         JALR64Pseudo, JALRHB64Pseudo,
                                         JALRHBPseudo, JALRPseudo, JR, JR64,
                                         PseudoIndirectBranch,
                                         PseudoIndirectBranch64, PseudoReturn,
                                         PseudoReturn64, RetRA, TAILCALL,
                                         TAILCALLREG, TAILCALLREG64)>;

// MULT, MULTU: 10 cycles, FP multiplier busy 4 (Table 2.2, Table 1.23)
def : InstRW<[R4600WriteMULT], (instrs MULT, MULTu, PseudoMULT, PseudoMULTu)>;

// DMULT, DMULTU: 12 cycles, FP multiplier busy 4 (Table 2.2, Table 1.23)
def : InstRW<[R4600WriteDMULT], (instrs DMULT, DMULTu, PseudoDMULT,
                                        PseudoDMULTu)>;

// SDIV, UDIV: 42 cycles, FP adder busy 4 (Table 2.2, Table 1.23)
def : InstRW<[R4600WriteDIV], (instrs PseudoSDIV, PseudoUDIV, SDIV, UDIV)>;

// DSDIV, DUDIV: 74 cycles, FP adder busy 4 (Table 2.2, Table 1.23)
def : InstRW<[R4600WriteDDIV], (instrs DSDIV, DUDIV, PseudoDSDIV, PseudoDUDIV)>;

// MFHI, MFLO: 2 cycles (Table 1.23); MTHI, MTLO: 2 (not in manual, assumed)
def : InstRW<[R4600WriteHILO], (instrs MFHI, MFHI64, MFLO, MFLO64, MTHI, MTHI64,
                                       MTLO, MTLO64, PseudoMFHI, PseudoMFHI64,
                                       PseudoMFLO, PseudoMFLO64, PseudoMTLOHI,
                                       PseudoMTLOHI64)>;

// FP ADD and SUB: 4 cycles (Table 1.19)
def : InstRW<[R4600WriteFPAdd], (instrs FADD_D32, FADD_D64, FADD_S, FSUB_D32,
                                        FSUB_D64, FSUB_S)>;

// FP compare: 3 cycles (Table 1.19)
def : InstRW<[R4600WriteFPCmp], (instrs C_EQ_D32, C_EQ_D64, C_EQ_S, C_F_D32,
                                        C_F_D64, C_F_S, C_LE_D32, C_LE_D64,
                                        C_LE_S, C_LT_D32, C_LT_D64, C_LT_S,
                                        C_NGE_D32, C_NGE_D64, C_NGE_S,
                                        C_NGLE_D32, C_NGLE_D64, C_NGLE_S,
                                        C_NGL_D32, C_NGL_D64, C_NGL_S,
                                        C_NGT_D32, C_NGT_D64, C_NGT_S,
                                        C_OLE_D32, C_OLE_D64, C_OLE_S,
                                        C_OLT_D32, C_OLT_D64, C_OLT_S,
                                        C_SEQ_D32, C_SEQ_D64, C_SEQ_S, C_SF_D32,
                                        C_SF_D64, C_SF_S, C_UEQ_D32, C_UEQ_D64,
                                        C_UEQ_S, C_ULE_D32, C_ULE_D64, C_ULE_S,
                                        C_ULT_D32, C_ULT_D64, C_ULT_S, C_UN_D32,
                                        C_UN_D64, C_UN_S, FCMP_D32, FCMP_D64,
                                        FCMP_S32)>;

// FP MUL: 8 cycles, multiplier busy 6 (Table 1.19; text line 1170)
def : InstRW<[R4600WriteFPMul], (instrs FMUL_D32, FMUL_D64, FMUL_S)>;

// FP DIV single: 32 cycles, unpipelined (Table 1.19; repeat rate assumed equal
// to latency)
def : InstRW<[R4600WriteFPDivS], (instrs FDIV_S)>;

// FP DIV double: 61 cycles, unpipelined (Table 1.19; repeat rate assumed equal
// to latency)
def : InstRW<[R4600WriteFPDivD], (instrs FDIV_D32, FDIV_D64)>;

// FP SQRT single: 31 cycles, unpipelined (Table 1.19; repeat rate assumed)
def : InstRW<[R4600WriteFPSqrtS], (instrs FSQRT_S)>;

// FP SQRT double: 60 cycles, unpipelined (Table 1.19; repeat rate assumed)
def : InstRW<[R4600WriteFPSqrtD], (instrs FSQRT_D32, FSQRT_D64)>;

// FP ABS, NEG, MOV: 1 cycle (Table 1.19)
def : InstRW<[R4600WriteFPMove], (instrs FABS_D32, FABS_D64, FABS_S, FMOV_D32,
                                         FMOV_D64, FMOV_S, FNEG_D32, FNEG_D64,
                                         FNEG_S)>;

// FP to fixed (FIX): 4 cycles (Table 1.19)
def : InstRW<[R4600WriteFPToInt], (instrs CEIL_L_D64, CEIL_L_S, CEIL_W_D32,
                                          CEIL_W_D64, CEIL_W_S, CVT_L_D64,
                                          CVT_L_S, CVT_W_D32, CVT_W_D64,
                                          CVT_W_S, FLOOR_L_D64, FLOOR_L_S,
                                          FLOOR_W_D32, FLOOR_W_D64, FLOOR_W_S,
                                          ROUND_L_D64, ROUND_L_S, ROUND_W_D32,
                                          ROUND_W_D64, ROUND_W_S, TRUNC_L_D64,
                                          TRUNC_L_S, TRUNC_W_D32, TRUNC_W_D64,
                                          TRUNC_W_S)>;

// Fixed to FP (FLOAT): 6 cycles (Table 1.19)
def : InstRW<[R4600WriteIntToFP], (instrs CVT_D32_W, CVT_D64_L, CVT_D64_W,
                                          CVT_S_L, CVT_S_W, PseudoCVT_D32_W,
                                          PseudoCVT_D64_L, PseudoCVT_D64_W,
                                          PseudoCVT_S_L, PseudoCVT_S_W)>;

// FP format conversion CVT.S.D and CVT.D.S: not in the manual, assumed as FIX
// (4 cycles)
def : InstRW<[R4600WriteFPFormat], (instrs CVT_D32_S, CVT_D64_S, CVT_S_D32,
                                           CVT_S_D64)>;

// LWC1, LDC1: 2 cycles (Table 1.19)
def : InstRW<[R4600WriteFPLoad], (instrs LDC1, LDC164, LWC1)>;

// SWC1, SDC1: 1 cycle (Table 1.19)
def : InstRW<[R4600WriteFPStore], (instrs SDC1, SDC164, SWC1)>;

// GPR-FPR and control moves: not in the manual, assumed 2 cycles
def : InstRW<[R4600WriteFPXfer], (instrs BuildPairF64, BuildPairF64_64, CFC1, CTC1, DMFC1,
                                         DMTC1, ExtractElementF64,
                                         ExtractElementF64_64, MFC1, MFC1_D64,
                                         MTC1, MTC1_D64)>;

// CP0 moves, TLB, cache, ERET, SYNC, WAIT: not in the manual, assumed 1 cycle
def : InstRW<[R4600WriteCop0], (instrs CACHE, DMFC0, DMTC0, ERET, ERet, MFC0,
                                       MTC0, PREF, RDHWR, RDHWR64, SYNC, TLBP,
                                       TLBR, TLBWI, TLBWR, WAIT)>;

// COP2 and COP3 transfers and loads and stores: not implemented on the R4600,
// assumed 1 cycle
def : InstRW<[R4600WriteCop2], (instrs DMFC2, DMTC2, LDC2, LDC3, LWC2, LWC3,
                                       MFC2, MTC2, SDC2, SDC3, SWC2, SWC3)>;

// Store-conditional: not in the manual, assumed 2 cycles
def : InstRW<[R4600WriteLLSC], (instrs ATOMIC_CMP_SWAP_I16_POSTRA,
                                       ATOMIC_CMP_SWAP_I32_POSTRA,
                                       ATOMIC_CMP_SWAP_I64_POSTRA,
                                       ATOMIC_CMP_SWAP_I8_POSTRA,
                                       ATOMIC_LOAD_ADD_I16_POSTRA,
                                       ATOMIC_LOAD_ADD_I32_POSTRA,
                                       ATOMIC_LOAD_ADD_I64_POSTRA,
                                       ATOMIC_LOAD_ADD_I8_POSTRA,
                                       ATOMIC_LOAD_AND_I16_POSTRA,
                                       ATOMIC_LOAD_AND_I32_POSTRA,
                                       ATOMIC_LOAD_AND_I64_POSTRA,
                                       ATOMIC_LOAD_AND_I8_POSTRA,
                                       ATOMIC_LOAD_MAX_I16_POSTRA,
                                       ATOMIC_LOAD_MAX_I32_POSTRA,
                                       ATOMIC_LOAD_MAX_I64_POSTRA,
                                       ATOMIC_LOAD_MAX_I8_POSTRA,
                                       ATOMIC_LOAD_MIN_I16_POSTRA,
                                       ATOMIC_LOAD_MIN_I32_POSTRA,
                                       ATOMIC_LOAD_MIN_I64_POSTRA,
                                       ATOMIC_LOAD_MIN_I8_POSTRA,
                                       ATOMIC_LOAD_NAND_I16_POSTRA,
                                       ATOMIC_LOAD_NAND_I32_POSTRA,
                                       ATOMIC_LOAD_NAND_I64_POSTRA,
                                       ATOMIC_LOAD_NAND_I8_POSTRA,
                                       ATOMIC_LOAD_OR_I16_POSTRA,
                                       ATOMIC_LOAD_OR_I32_POSTRA,
                                       ATOMIC_LOAD_OR_I64_POSTRA,
                                       ATOMIC_LOAD_OR_I8_POSTRA,
                                       ATOMIC_LOAD_SUB_I16_POSTRA,
                                       ATOMIC_LOAD_SUB_I32_POSTRA,
                                       ATOMIC_LOAD_SUB_I64_POSTRA,
                                       ATOMIC_LOAD_SUB_I8_POSTRA,
                                       ATOMIC_LOAD_UMAX_I16_POSTRA,
                                       ATOMIC_LOAD_UMAX_I32_POSTRA,
                                       ATOMIC_LOAD_UMAX_I64_POSTRA,
                                       ATOMIC_LOAD_UMAX_I8_POSTRA,
                                       ATOMIC_LOAD_UMIN_I16_POSTRA,
                                       ATOMIC_LOAD_UMIN_I32_POSTRA,
                                       ATOMIC_LOAD_UMIN_I64_POSTRA,
                                       ATOMIC_LOAD_UMIN_I8_POSTRA,
                                       ATOMIC_LOAD_XOR_I16_POSTRA,
                                       ATOMIC_LOAD_XOR_I32_POSTRA,
                                       ATOMIC_LOAD_XOR_I64_POSTRA,
                                       ATOMIC_LOAD_XOR_I8_POSTRA,
                                       ATOMIC_SWAP_I16_POSTRA,
                                       ATOMIC_SWAP_I32_POSTRA,
                                       ATOMIC_SWAP_I64_POSTRA,
                                       ATOMIC_SWAP_I8_POSTRA, SC, SC64, SCD)>;

// Traps, SYSCALL, BREAK: not in the manual, assumed 1 cycle
def : InstRW<[R4600WriteTrap], (instrs BREAK, SYSCALL, TEQ, TEQI, TGE, TGEI,
                                       TGEIU, TGEU, TLT, TLTI, TLTU, TNE, TNEI,
                                       TRAP, TTLTIU)>;

} // let SchedModel = MipsR4600Model
