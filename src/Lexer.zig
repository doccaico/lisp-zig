const std = @import("std");

// pub const TokenTag = enum(u8) {
//     Integer,
//     Float,
//     String,
//     BinaryOp,
//     Keyword,
//     Symbol,
//     If,
//     LParen,
//     RParen,
// };

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

// Error
const TokenError = error{
    UnterminatedString,
};

pub fn tokenize(allocator: std.mem.Allocator, input: []const u8) anyerror!std.ArrayList(Token) {
    var tokens = std.ArrayList(Token).init(allocator);

    var chars = try std.ArrayList(u8).initCapacity(allocator, input.len);
    chars.appendSliceAssumeCapacity(input);

    if (chars.items.len == 0) {
        return tokens;
    }
    while (chars.items.len > 0) {
        var ch = chars.orderedRemove(0);
        switch (ch) {
            '(' => try tokens.append(Token{ .LParen = .{} }),
            ')' => try tokens.append(Token{ .RParen = .{} }),
            '"' => {
                var word = std.ArrayList(u8).init(allocator);
                while (chars.items.len > 0 and chars.items[0] != '"') {
                    try word.append(chars.orderedRemove(0));
                }

                if (chars.items.len > 0 and chars.items[0] == '"') {
                    _ = chars.orderedRemove(0);
                } else {
                    return TokenError.UnterminatedString;
                }
                try tokens.append(Token{ .String = .{ .value = word.items } });
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

                var token: Token = undefined;
                if (word.items.len != 0) {
                    if (isInteger(word.items)) {
                        token = Token{ .Integer = .{ .value = try std.fmt.parseInt(i64, word.items, 10) } };
                    } else if (isFloat(word.items)) {
                        token = Token{ .Float = .{ .value = try std.fmt.parseFloat(f64, word.items) } };
                    } else {
                        if (isKeyword(word.items)) {
                            token = Token{ .Keyword = .{ .value = word.items } };
                        } else if (isIf(word.items)) {
                            token = Token{ .If = .{} };
                        } else if (isBinaryOp(word.items)) {
                            token = Token{ .BinaryOp = .{ .value = word.items } };
                        } else {
                            token = Token{ .Symbol = .{ .value = word.items } };
                        }
                    }
                }
                try tokens.append(token);
            },
        }
    }
    return tokens;
}

fn isInteger(word: []const u8) bool {
    _ = std.fmt.parseInt(i64, word, 10) catch {
        return false;
    };
    return true;
}

fn isFloat(word: []const u8) bool {
    _ = std.fmt.parseFloat(f64, word) catch {
        return false;
    };
    return true;
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

    const tokens = try tokenize(allocator, "(+ 1 2)");

    const expected = [_]Token{
        Token{ .LParen = .{} },
        Token{ .BinaryOp = .{ .value = "+" } },
        Token{ .Integer = .{ .value = 1 } },
        Token{ .Integer = .{ .value = 2 } },
        Token{ .RParen = .{} },
    };

    comptime var i: usize = 0;
    inline while (i < expected.len) : (i += 1) {
        try std.testing.expectEqualDeep(expected[i], tokens.items[i]);
    }
}
