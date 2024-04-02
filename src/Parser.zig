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
            .Keyword => |x| try list.append(.{ .Keyword = .{ .value = x.value } }),
            .If => try list.append(.{ .If = .{} }),
            .BinaryOp => |x| try list.append(.{ .BinaryOp = .{ .value = x.value } }),
            .Integer => |x| try list.append(.{ .Integer = .{ .value = x.value } }),
            .Float => |x| try list.append(.{ .Float = .{ .value = x.value } }),
            .String => |x| try list.append(.{ .String = .{ .value = x.value } }),
            .Symbol => |x| try list.append(.{ .Symbol = .{ .value = x.value } }),
            .LParen => {
                try tokens.append(.{ .LParen = .{} });
                const sub_list = try parse_list(allocator, tokens);
                try list.append(sub_list);
            },
            .RParen => {
                return .{ .List = .{ .list = list } };
            },
        }
    }
    return .{ .List = .{ .list = list } };
}

test "test_add" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const actual = try parse(allocator, "(+ 1 2)");

    var a1 = std.ArrayList(Object.Object).init(allocator);
    try a1.append(.{ .BinaryOp = .{ .value = "+" } });
    try a1.append(.{ .Integer = .{ .value = 1 } });
    try a1.append(.{ .Integer = .{ .value = 2 } });

    const expected: Object.Object = .{ .List = .{ .list = a1 } };

    try std.testing.expectEqualDeep(expected, actual);
}

test "test_area_of_a_circle" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const program =
        \\(
        \\    (define r 10)
        \\    (define pi 314)
        \\    (* pi (* r r))
        \\)
    ;

    const actual = try parse(allocator, program);

    const list1 = blk: {
        var a = std.ArrayList(Object.Object).init(allocator);
        try a.append(.{ .Keyword = .{ .value = "define" } });
        try a.append(.{ .Symbol = .{ .value = "r" } });
        try a.append(.{ .Integer = .{ .value = 10 } });
        break :blk .{ .List = .{ .list = a } };
    };

    const list2 = blk: {
        var a = std.ArrayList(Object.Object).init(allocator);
        try a.append(.{ .Keyword = .{ .value = "define" } });
        try a.append(.{ .Symbol = .{ .value = "pi" } });
        try a.append(.{ .Integer = .{ .value = 314 } });
        break :blk .{ .List = .{ .list = a } };
    };

    const list3 = blk: {
        var b = std.ArrayList(Object.Object).init(allocator);
        try b.append(.{ .BinaryOp = .{ .value = "*" } });
        try b.append(.{ .Symbol = .{ .value = "r" } });
        try b.append(.{ .Symbol = .{ .value = "r" } });

        var a = std.ArrayList(Object.Object).init(allocator);
        try a.append(.{ .BinaryOp = .{ .value = "*" } });
        try a.append(.{ .Symbol = .{ .value = "pi" } });
        try a.append(.{
            .List = .{ .list = b },
        });
        break :blk .{ .List = .{ .list = a } };
    };

    var list = std.ArrayList(Object.Object).init(allocator);
    try list.append(list1);
    try list.append(list2);
    try list.append(list3);

    const expected: Object.Object = .{
        .List = .{ .list = list },
    };

    try std.testing.expectEqualDeep(expected, actual);
}
