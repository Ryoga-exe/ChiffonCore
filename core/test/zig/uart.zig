const base = 0x10000000;
const rbr: *volatile u8 = @ptrFromInt(base + 0x00); // read
const thr: *volatile u8 = @ptrFromInt(base + 0x00); // write
const lsr: *volatile u8 = @ptrFromInt(base + 0x05); // status

pub fn init() void {}

pub fn putChar(c: u8) void {
    if (c == '\n') {
        putChar('\r');
    }
    while ((lsr.* & 0x20) == 0) {}
    thr.* = c;
}

pub fn putString(s: []const u8) void {
    for (s) |c| {
        putChar(c);
    }
}
