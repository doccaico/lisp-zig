const std = @import("std");

const Lexer = @import("Lexer.zig");
const Object = @import("Object.zig");

pub fn parse(allocator: std.mem.Allocator, program: []const u8) !Object.Object {
    var token_result = try Lexer.tokenize(allocator, program);

    const cloned = try token_result.clone();
    std.mem.reverse(Lexer.Token, cloned.items[0..]);
    const parsed_list = parse_list(cloned);

    return parsed_list;
}

fn parse_list(tokens: std.ArrayList(Lexer.Token)) Object.Object {
    _ = tokens;
    return Object.Object{ .Integer = Object.Integer{ .value = 1 } };
}

test "test_add" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const tokenized = try parse(allocator, "(+ 1 2)");

    var a1 = std.ArrayList(Object.Object).init(allocator);
    try a1.append(.{ .BinaryOp = .{ .value = "+" } });
    try a1.append(.{ .Integer = .{ .value = 1 } });
    try a1.append(.{ .Integer = .{ .value = 2 } });

    const expected = [_]Object.Object{
        // .{ .List = a1 },
        .{ .List = .{ .list = a1 } },
    };

    try std.testing.expectEqualDeep(expected[0..], tokenized.List.list.items);
}
