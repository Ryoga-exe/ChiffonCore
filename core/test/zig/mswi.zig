const uart = @import("uart.zig");

const msip0: *volatile u32 = @ptrFromInt(0x2000000);
const mie_msie: u64 = 1 << 3;
const mstatus_mie: u64 = 1 << 3;

inline fn csrw(comptime csr: []const u8, x: u64) void {
    asm volatile ("csrw " ++ csr ++ ", %[val]"
        :
        : [val] "r" (x),
        : .{ .memory = true });
}

export fn interrupt_handler() callconv(.{ .riscv64_interrupt = .{ .mode = .machine } }) void {
    uart.putString("OK\n");
}

pub export fn main() callconv(.c) noreturn {
    csrw("mtvec", @intFromPtr(&interrupt_handler));
    csrw("mie", mie_msie);
    csrw("mstatus", mstatus_mie);

    msip0.* = 1;

    uart.putString("NG\n"); // fail

    while (true) {}
}
