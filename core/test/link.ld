OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x80000000;

  .text.init : ALIGN(4) {
    KEEP(*(.text.init))
  }

  .text : ALIGN(4) {
    *(.text .text.*)
  }

  .rodata : ALIGN(4) {
    *(.srodata .srodata.* .rodata .rodata.* .rodata.str1.1)
  }

  .data : ALIGN(8) {
    *(.sdata .sdata.* .data .data.*)
  }

  .bss : ALIGN(8) {
    *(.sbss .sbss.* .bss .bss.* COMMON)
  }

  .stack : ALIGN(16) {
    _stack_top = .;
    . += 4K;
    _stack_bottom = .;
  }

  _end = .;

  /DISCARD/ : {
    *(.eh_frame .eh_frame.* .comment .note.*)
  }
}
