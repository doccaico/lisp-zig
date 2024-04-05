const std = @import("std");

pub const Token = union(enum(u8)) {
    Integer: Integer,
    Float: Float,
    String: String,
    BinaryOp: BinaryOp,
    Keyword: Keyword,
    Symbol: Symbol,
    If: If,
    LParen: LParen,
    RParen: RParen,

    pub fn string(self: Token, writer: anytype) !void {
        return switch (self) {
            inline else => |x| x.string(writer),
        };
    }
};

pub const Integer = struct {
    value: i64,

    pub fn string(self: Integer, writer: anytype) !void {
        try writer.print("{d}", .{self.value});
    }
};

pub const Float = struct {
    value: f64,

    pub fn string(self: Float, writer: anytype) !void {
        try writer.print("{f}", .{self.value});
    }
};

pub const String = struct {
    value: []const u8,

    pub fn string(self: String, writer: anytype) !void {
        try writer.writeAll(self.value);
    }
};

pub const BinaryOp = struct {
    value: []const u8,

    pub fn string(self: BinaryOp, writer: anytype) !void {
        try writer.writeAll(self.value);
    }
};

pub const Keyword = struct {
    value: []const u8,

    pub fn string(self: Keyword, writer: anytype) !void {
        try writer.writeAll(self.value);
    }
};

pub const Symbol = struct {
    value: []const u8,

    pub fn string(self: Symbol, writer: anytype) !void {
        try writer.writeAll(self.value);
    }
};

pub const If = struct {
    pub fn string(_: If, writer: anytype) !void {
        try writer.writeAll("if");
    }
};

pub const LParen = struct {
    pub fn string(_: LParen, writer: anytype) !void {
        try writer.writeAll("()");
    }
};

pub const RParen = struct {
    pub fn string(_: RParen, writer: anytype) !void {
        try writer.writeAll(")");
    }
};

pub fn tokenize(allocator: std.mem.Allocator, input: []const u8) !std.ArrayList(Token) {
    var tokens = std.ArrayList(Token).init(allocator);

    var chars = try std.ArrayList(u8).initCapacity(allocator, input.len);
    chars.appendSliceAssumeCapacity(input);

    if (chars.items.len == 0) {
        return tokens;
    }
    while (chars.items.len > 0) {
        var ch = chars.orderedRemove(0);
        switch (ch) {
            '(' => {
                try tokens.append(.{ .LParen = .{} });
            },
            ')' => try tokens.append(.{ .RParen = .{} }),
            '"' => {
                var word = std.ArrayList(u8).init(allocator);
                while (chars.items.len > 0 and chars.items[0] != '"') {
                    try word.append(chars.orderedRemove(0));
                }

                if (chars.items.len > 0 and chars.items[0] == '"') {
                    _ = chars.orderedRemove(0);
                } else {
                    return error.UnterminatedString;
                }
                try tokens.append(.{ .String = .{ .value = word.items } });
            },
            else => {
                var word = std.ArrayList(u8).init(allocator);
                while (chars.items.len > 0 and !std.ascii.isWhitespace(ch) and ch != '(' and ch != ')') {
                    try word.append(ch);
                    const peek = chars.items[0];
                    if (peek == '(' or peek == ')') {
                        break;
                    }
                    ch = chars.orderedRemove(0);
                }

                if (word.items.len != 0) {
                    const token: Token = blk: {
                        const integer_result = isInteger(word.items);
                        if (integer_result.ok) break :blk .{ .Integer = .{ .value = integer_result.value } };
                        const float_result = isFloat(word.items);
                        if (float_result.ok) break :blk .{ .Float = .{ .value = float_result.value } };
                        if (isKeyword(word.items)) break :blk .{ .Keyword = .{ .value = word.items } };
                        if (isIf(word.items)) break :blk .{ .If = .{} };
                        if (isBinaryOp(word.items)) break :blk .{ .BinaryOp = .{ .value = word.items } };
                        break :blk .{ .Symbol = .{ .value = word.items } };
                    };
                    try tokens.append(token);
                }
            },
        }
    }
    return tokens;
}

const isIntegerResult = struct {
    value: i64 = undefined,
    ok: bool,
};

fn isInteger(word: []const u8) isIntegerResult {
    const value = std.fmt.parseInt(i64, word, 10) catch {
        return .{ .ok = false };
    };
    return .{ .value = value, .ok = true };
}

const isFloatResult = struct {
    value: f64 = undefined,
    ok: bool,
};

fn isFloat(word: []const u8) isFloatResult {
    const value = std.fmt.parseFloat(f64, word) catch {
        return .{ .ok = false };
    };
    return .{ .value = value, .ok = true };
}

fn isKeyword(word: []const u8) bool {
    const keywords = [_][]const u8{
        "define",
        "list",
        "print",
        "lambda",
        "map",
        "filter",
        "reduce",
        "range",
        "car",
        "cdr",
        "length",
        "null?",
        "begin",
        "let",
    };
    for (keywords) |keyword| {
        if (std.mem.eql(u8, word, keyword)) {
            return true;
        }
    }
    return false;
}

fn isIf(word: []const u8) bool {
    return std.mem.eql(u8, word, "if");
}

fn isBinaryOp(word: []const u8) bool {
    const binary_ops = [_][]const u8{ "+", "-", "*", "/", "%", "<", ">", "=", "!=", "or", "and" };
    for (binary_ops) |op| {
        if (std.mem.eql(u8, word, op)) {
            return true;
        }
    }
    return false;
}

test "test_add" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const actual = try tokenize(allocator, "(+ 1 2)");

    const expected = [_]Token{
        .{ .LParen = .{} },
        .{ .BinaryOp = .{ .value = "+" } },
        .{ .Integer = .{ .value = 1 } },
        .{ .Integer = .{ .value = 2 } },
        .{ .RParen = .{} },
    };

    try std.testing.expectEqualDeep(expected[0..], actual.items);
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

    const actual = try tokenize(allocator, program);

    const expected = [_]Token{
        .{ .LParen = .{} },
        .{ .LParen = .{} },
        .{ .Keyword = .{ .value = "define" } },
        .{ .Symbol = .{ .value = "r" } },
        .{ .Integer = .{ .value = 10 } },
        .{ .RParen = .{} },
        .{ .LParen = .{} },
        .{ .Keyword = .{ .value = "define" } },
        .{ .Symbol = .{ .value = "pi" } },
        .{ .Integer = .{ .value = 314 } },
        .{ .RParen = .{} },
        .{ .LParen = .{} },
        .{ .BinaryOp = .{ .value = "*" } },
        .{ .Symbol = .{ .value = "pi" } },
        .{ .LParen = .{} },
        .{ .BinaryOp = .{ .value = "*" } },
        .{ .Symbol = .{ .value = "r" } },
        .{ .Symbol = .{ .value = "r" } },
        .{ .RParen = .{} },
        .{ .RParen = .{} },
        .{ .RParen = .{} },
    };

    try std.testing.expectEqualDeep(expected[0..], actual.items);
}

test "test_error_unterminated_string" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try std.testing.expectError(error.UnterminatedString, tokenize(allocator, "(define foo \"bar)"));
}
