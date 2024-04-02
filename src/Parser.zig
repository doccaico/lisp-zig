const std = @import("std");

const Lexer = @import("Lexer.zig");
const Object = @import("Object.zig");

pub fn parse(allocator: std.mem.Allocator, program: []const u8) !Object.Object {
    var token_result = try Lexer.tokenize(allocator, program);

    var cloned = try token_result.clone();
    std.mem.reverse(Lexer.Token, cloned.items[0..]);
    const parsed_list = parse_list(allocator, &cloned);

    return parsed_list;
}

fn parse_list(allocator: std.mem.Allocator, tokens: *std.ArrayList(Lexer.Token)) !Object.Object {
    const t = tokens.pop();
    switch (t) {
        .LParen => {},
        else => {
            return error.ExpectedLParen;
        },
    }

    var list = std.ArrayList(Object.Object).init(allocator);
    while (tokens.items.len != 0) {
        const token = tokens.popOrNull() orelse return error.NotEnoughTokens;
        switch (token) {
            .Keyword => |x| try list.append(Object.Object{ .Keyword = Object.Keyword{ .value = x.value } }),
            .If => try list.append(Object.Object{ .If = .{} }),
            .BinaryOp => |x| try list.append(Object.Object{ .BinaryOp = Object.BinaryOp{ .value = x.value } }),
            .Integer => |x| try list.append(Object.Object{ .Integer = Object.Integer{ .value = x.value } }),
            .Float => |x| try list.append(Object.Object{ .Float = Object.Float{ .value = x.value } }),
            .String => |x| try list.append(Object.Object{ .String = Object.String{ .value = x.value } }),
            .Symbol => |x| try list.append(Object.Object{ .Symbol = Object.Symbol{ .value = x.value } }),
            .LParen => {
                try tokens.append(Lexer.Token{ .LParen = .{} });
                const sub_list = try parse_list(allocator, tokens);
                try list.append(sub_list);
            },
            .RParen => {
                return Object.Object{ .List = Object.List{ .list = list } };
            },
        }
    }
    return Object.Object{ .List = Object.List{ .list = list } };
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

    const expected = Object.Object{ .List = Object.List{ .list = a1 } };

    try std.testing.expectEqualDeep(expected, tokenized);
}
