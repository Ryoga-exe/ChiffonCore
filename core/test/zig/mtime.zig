const uart = @import("uart.zig");

const mtimecmp0: *volatile u32 = @ptrFromInt(0x0200_4000);
const mtime: *volatile u32 = @ptrFromInt(0x0200_7ff8);

const mie_mtie: u64 = 1 << 7;
const mstatus_mie: u64 = 1 << 3;

inline fn csrw(comptime csr: []const u8, x: u64) void {
    asm volatile ("csrw " ++ csr ++ ", %[val]"
        :
        : [val] "r" (x),
        : .{ .memory = true });
}

export fn interrupt_handler() void {
    uart.putString("OK\n");
}

export fn main() noreturn {
    csrw("mtvec", @intFromPtr(&interrupt_handler));

    const now: u32 = mtime.*;
    mtimecmp0.* = now + 1_000_000;

    csrw("mie", mie_mtie);
    csrw("mstatus", mstatus_mie);

    while (true) {}

    // 到達しない
}
