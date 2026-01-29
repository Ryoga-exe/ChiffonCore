const uart = @import("uart.zig");

const msip0: *volatile u32 = @ptrFromInt(0x2000000);
const mie_msie: u64 = 1 << 3;
const mstatus_mie: u64 = 1 << 3;

// CSR write helpers
inline fn w_mtvec(x: u64) void {
    asm volatile ("csrw mtvec, %[val]"
        :
        : [val] "r" (x),
        : .{ .memory = true });
}
inline fn w_mie(x: u64) void {
    asm volatile ("csrw mie, %[val]"
        :
        : [val] "r" (x),
        : .{ .memory = true });
}
inline fn w_mstatus(x: u64) void {
    asm volatile ("csrw mstatus, %[val]"
        :
        : [val] "r" (x),
        : .{ .memory = true });
}

export fn interrupt_handler() callconv(.riscv64_interrupt) void {
    uart.putChar('1');
}

pub export fn main() callconv(.c) noreturn {
    w_mtvec(@intFromPtr(&interrupt_handler));
    w_mie(mie_msie);
    w_mstatus(mstatus_mie);

    msip0.* = 1;

    while (true) {
        uart.putChar('3'); // fail
    }
}
