# Spec

## Instructions

c.f: https://msyksphinz-self.github.io/riscv-isadoc/html/index.html

| Instruction Set | Instruction | Status |
| --------------- | ----------- | ------ |
| RV64I (RV32I)   | lui         | ✅     |
|                 | auipc       | ✅     |
|                 | addi        | ✅     |
|                 | slti        | ✅     |
|                 | sltiu       | ✅     |
|                 | xori        | ✅     |
|                 | ori         | ✅     |
|                 | andi        | ✅     |
|                 | slli        | ✅     |
|                 | srli        | ✅     |
|                 | srai        | ✅     |
|                 | add         | ✅     |
|                 | sub         | ✅     |
|                 | sll         | ✅     |
|                 | slt         | ✅     |
|                 | sltu        | ✅     |
|                 | xor         | ✅     |
|                 | srl         | ✅     |
|                 | sra         | ✅     |
|                 | or          | ✅     |
|                 | and         | ✅     |
|                 | fence       | 🟨     |
|                 | fence.i     | 🟨     |
|                 | csrrw       | ✅     |
|                 | csrrs       | ✅     |
|                 | csrrc       | ✅     |
|                 | csrrwi      | ✅     |
|                 | csrrsi      | ✅     |
|                 | csrrci      | ✅     |
|                 | ecall       | ✅     |
|                 | ebreak      | ✅     |
|                 | uret        |        |
|                 | sret        |        |
|                 | mret        | ✅     |
|                 | wfi         |        |
|                 | sfence.vma  |        |
|                 | lb          | ✅     |
|                 | lh          | ✅     |
|                 | lw          | ✅     |
|                 | lbu         | ✅     |
|                 | lhu         | ✅     |
|                 | sb          | ✅     |
|                 | sh          | ✅     |
|                 | sw          | ✅     |
|                 | jal         | ✅     |
|                 | jalr        | ✅     |
|                 | beq         | ✅     |
|                 | bne         | ✅     |
|                 | blt         | ✅     |
|                 | bge         | ✅     |
|                 | bltu        | ✅     |
|                 | bgeu        | ✅     |
| RV64I           | addiw       | ✅     |
|                 | slliw       | ✅     |
|                 | srliw       | ✅     |
|                 | sraiw       | ✅     |
|                 | addw        | ✅     |
|                 | subw        | ✅     |
|                 | sllw        | ✅     |
|                 | srlw        | ✅     |
|                 | sraw        | ✅     |
|                 | lwu         | ✅     |
|                 | ld          | ✅     |
|                 | sd          | ✅     |
| RV64M (RV32M)   | mul         | ✅     |
|                 | mulh        | ✅     |
|                 | mulhsu      | ✅     |
|                 | mulhu       | ✅     |
|                 | div         | ✅     |
|                 | divu        | ✅     |
|                 | rem         | ✅     |
|                 | remu        | ✅     |
| RV64M           | mulw        | ✅     |
|                 | divw        | ✅     |
|                 | divuw       | ✅     |
|                 | remw        | ✅     |
|                 | remuw       | ✅     |
| RV64A (RV32A)   | lr.w        | wip    |
|                 | sc.w        | wip    |
|                 | amoswap.w   |        |
|                 | amoadd.w    |        |
|                 | amoxor.w    |        |
|                 | amoand.w    |        |
|                 | amoor.w     |        |
|                 | amomin.w    |        |
|                 | amomax.w    |        |
|                 | amominu.w   |        |
|                 | amomaxu.w   |        |
| RV64A           | lr.d        | wip    |
|                 | sc.d        | wip    |
|                 | amoswap.d   |        |
|                 | amoadd.d    |        |
|                 | amoxor.d    |        |
|                 | amoand.d    |        |
|                 | amoor.d     |        |
|                 | amomin.d    |        |
|                 | amomax.d    |        |
|                 | amominu.d   |        |
|                 | amomaxu.d   |        |
| RV64D (RV32F)   | fmadd.s     |        |
|                 | fmsub.s     |        |
|                 | fnmsub.s    |        |
|                 | fnmadd.s    |        |
|                 | fadd.s      |        |
|                 | fsub.s      |        |
|                 | fmul.s      |        |
|                 | fdiv.s      |        |
|                 | fsqrt.s     |        |
|                 | fsgnj.s     |        |
|                 | fsgnjn.s    |        |
|                 | fsgnjx.s    |        |
|                 | fmin.s      |        |
|                 | fmax.s      |        |
|                 | fcvt.w.s    |        |
|                 | fcvt.wu.s   |        |
|                 | fmv.x.w     |        |
|                 | feq.s       |        |
|                 | flt.s       |        |
|                 | fle.s       |        |
|                 | fclass.s    |        |
|                 | fcvt.s.w    |        |
|                 | fcvt.s.wu   |        |
|                 | fmv.w.x     |        |
|                 | fmadd.d     |        |
|                 | fmsub.d     |        |
|                 | fnmsub.d    |        |
|                 | fnmadd.d    |        |
|                 | fadd.d      |        |
|                 | fsub.d      |        |
|                 | fmul.d      |        |
|                 | fdiv.d      |        |
|                 | fsqrt.d     |        |
|                 | fsgnj.d     |        |
|                 | fsgnjn.d    |        |
|                 | fsgnjx.d    |        |
|                 | fmin.d      |        |
|                 | fmax.d      |        |
|                 | fcvt.s.d    |        |
|                 | fcvt.d.s    |        |
|                 | feq.d       |        |
|                 | flt.d       |        |
|                 | fle.d       |        |
|                 | fclass.d    |        |
|                 | fcvt.w.d    |        |
|                 | fcvt.wu.d   |        |
|                 | fcvt.d.w    |        |
|                 | fcvt.d.wu   |        |
|                 | flw         |        |
|                 | fsw         |        |
|                 | fld         |        |
|                 | fsd         |        |
| RV64F           | fcvt.l.s    |        |
|                 | fcvt.lu.s   |        |
|                 | fcvt.s.l    |        |
|                 | fcvt.s.lu   |        |
| RV64D           | fcvt.l.d    |        |
|                 | fcvt.lu.d   |        |
|                 | fmv.x.d     |        |
|                 | fcvt.d.l    |        |
|                 | fcvt.d.lu   |        |
|                 | fmv.d.x     |        |
| RV64C (RV32C)   | c.addi4spn  |        |
|                 | c.fld       |        |
|                 | c.lw        |        |
|                 | c.flw       |        |
|                 | c.ld        |        |
|                 | c.fsd       |        |
|                 | c.sw        |        |
|                 | c.fsw       |        |
|                 | c.sd        |        |
|                 | c.nop       |        |
|                 | c.addi      |        |
|                 | c.jal       |        |
|                 | c.addiw     |        |
|                 | c.li        |        |
|                 | c.addi16sp  |        |
|                 | c.lui       |        |
|                 | c.srli      |        |
|                 | c.srai      |        |
|                 | c.andi      |        |
|                 | c.sub       |        |
|                 | c.xor       |        |
|                 | c.or        |        |
|                 | c.and       |        |
|                 | c.subw      |        |
|                 | c.addw      |        |
|                 | c.j         |        |
|                 | c.beqz      |        |
|                 | c.bnez      |        |
|                 | c.slli      |        |
|                 | c.fldsp     |        |
|                 | c.lwsp      |        |
|                 | c.flwsp     |        |
|                 | c.ldsp      |        |
|                 | c.jr        |        |
|                 | c.mv        |        |
|                 | c.ebreak    |        |
|                 | c.jalr      |        |
|                 | c.add       |        |
|                 | c.fsdsp     |        |
|                 | c.swsp      |        |
|                 | c.fswsp     |        |
|                 | c.sdsp      |        |
