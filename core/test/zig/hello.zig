const uart = @import("uart.zig");

pub export fn main() callconv(.c) noreturn {
    uart.putString("Hello,world!\n");
    while (true) {}
}
