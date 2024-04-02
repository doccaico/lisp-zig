const std = @import("std");

const Lexer = @import("Env.zig");
const Object = @import("Object.zig");

const ParseResult = union(enum(u8)) {
    result: Object,
    errmsg: []const u8,
};

pub fn parse(allocator: std.mem.Allocator, program: []const u8) !ParseResult {
    const token_result = try Lexer.tokenize(program) catch |err| {
        return .{ .errmsg = try std.fmt.allocPrint(allocator, "Parse error: {s}", .{err}) };
    };
    if (token_result.errmsg.len != 0) {
        return .{ .errmsg = try std.fmt.allocPrint(allocator, "Parse error: {s}", .{token_result.errmsg}) };
    }
}
