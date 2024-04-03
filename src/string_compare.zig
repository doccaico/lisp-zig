const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const print = std.debug.print;
const assert = std.debug.assert;
const expect = std.testing.expect;

pub fn main() !void {
    const a = "abc";
    const b = "abc";

    const r = mem.order(u8, a, b);

    print("{any}\n", .{r == std.math.Order.eq});
}
