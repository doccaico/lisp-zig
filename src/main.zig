const std = @import("std");

const repl = @import("Repl.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    try repl.start(allocator, stdin, stdout);
}

test {
    _ = @import("Eval.zig");
    _ = @import("Lexer.zig");
    _ = @import("Parser.zig");
}
