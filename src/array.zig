const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const print = std.debug.print;
const assert = std.debug.assert;
const expect = std.testing.expect;

pub fn main() !void {
    const array = [_][]const u8{ "a", "b" };

    print("{s}\n", .{array[0]});
}
// zig test filename.zig
// test "if" {
//     try expect(1 == 1);
// }
//  const stdout = std.io.getStdOut().writer();
//  const message: []const u8 = "Hello, World!";
//  try stdout.print("{s}\n", .{message});
