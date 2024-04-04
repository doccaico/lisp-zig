const builtin = @import("builtin");
const std = @import("std");

const Env = @import("Env.zig");
const Eval = @import("Eval.zig");
const Lexer = @import("Lexer.zig");
const Parser = @import("Parser.zig");

const PROMPT = "lisp-zig> ";
const DELIMITER = if (builtin.os.tag == .windows) '\r' else '\n';

pub fn start(allocator: std.mem.Allocator, stdin: anytype, stdout: anytype) !void {
    const env = try Env.init(allocator);

    loop: while (true) {
        try stdout.writeAll(PROMPT);

        var input = std.ArrayList(u8).init(allocator);

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

        const val = try Eval.eval(allocator, line, env);

        switch (val) {
            .Void => {},
            .Integer => |x| try stdout.print("{d}\n", .{x.value}),
            .String => |x| try stdout.print("{s}\n", .{x.value}),
            .Bool => |x| try stdout.print("{}\n", .{x.value}),
            .Symbol => |x| try stdout.print("{s}\n", .{x.value}),
            // .List => |x| {
            //     try stdout.print("{s}\n", .{x.list.items[0].String.value});
            // },
            else => try stdout.print("{any}\n", .{val}),
        }

        // try result.inspect(stdout);
        // try stdout.writeByte('\n');

        input.clearRetainingCapacity();
    }
    try stdout.print("Good bye", .{});
}
