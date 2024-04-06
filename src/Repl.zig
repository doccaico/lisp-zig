const builtin = @import("builtin");
const std = @import("std");

const Env = @import("Env.zig");
const Eval = @import("Eval.zig");

const PROMPT = "lisp-zig> ";
const DELIMITER = if (builtin.os.tag == .windows) '\r' else '\n';

pub fn start(allocator: std.mem.Allocator, stdin: anytype, stdout: anytype) !void {
    var env = try Env.init(allocator);

    var input = std.ArrayList(u8).init(allocator);

    loop: while (true) {
        try stdout.writeAll(PROMPT);

        stdin.streamUntilDelimiter(input.writer(), DELIMITER, null) catch |err| switch (err) {
            error.EndOfStream => {
                input.deinit();
                break :loop;
            },
            else => |x| return x,
        };

        const space = if (builtin.os.tag == .windows) " \n" else " ";
        const line = std.mem.trim(u8, input.items, space);
        if (line.len == 0) {
            input.clearRetainingCapacity();
            continue;
        }

        if (std.mem.eql(u8, line, "exit")) {
            break :loop;
        }

        const val = try Eval.eval(allocator, line, &env);

        try val.inspect(stdout);
        try stdout.writeByte('\n');

        input.clearRetainingCapacity();
    }

    try stdout.print("Good bye", .{});
}
