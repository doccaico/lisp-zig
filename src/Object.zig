const std = @import("std");

const Env = @import("Env.zig");

pub const Object = union(enum(u8)) {
    Void: void,
    If: void,
    Keyword: Keyword,
    BinaryOp: BinaryOp,
    Integer: Integer,
    Float: Float,
    Bool: Bool,
    String: String,
    Symbol: Symbol,
    ListData: ListData,
    Lambda: Lambda,
    List: List,

    pub fn inspect(self: Object, writer: anytype) anyerror!void {
        return switch (self) {
            .Void, .If => {},
            inline else => |x| x.inspect(writer),
        };
    }
};

// pub const Void = struct {};

// pub const If = struct {};

pub const Keyword = struct {
    value: []const u8,

    pub fn inspect(self: Keyword, writer: anytype) !void {
        try writer.writeAll(self.value);
    }
};

pub const BinaryOp = struct {
    value: []const u8,

    pub fn inspect(self: BinaryOp, writer: anytype) !void {
        try writer.writeAll(self.value);
    }
};

pub const Integer = struct {
    value: i64,

    pub fn inspect(self: Integer, writer: anytype) !void {
        try writer.print("{d}", .{self.value});
    }
};

pub const Float = struct {
    value: f64,

    pub fn inspect(self: Float, writer: anytype) !void {
        try writer.print("{d}", .{self.value});
    }
};

pub const Bool = struct {
    value: bool,
    pub fn inspect(self: Bool, writer: anytype) !void {
        try writer.print("{}", .{self.value});
    }
};

pub const String = struct {
    value: []const u8,

    pub fn inspect(self: String, writer: anytype) !void {
        try writer.writeAll("\"");
        try writer.writeAll(self.value);
        try writer.writeAll("\"");
    }
};

pub const Symbol = struct {
    value: []const u8,

    pub fn inspect(self: Symbol, writer: anytype) !void {
        try writer.writeAll(self.value);
    }
};

pub const ListData = struct {
    list: std.ArrayList(Object),

    pub fn inspect(self: ListData, writer: anytype) !void {
        try writer.writeAll("(");

        for (self.list.items, 0..) |obj, i| {
            if (i > 0) {
                try writer.writeAll(" ");
            }
            try obj.inspect(writer);
        }

        try writer.writeAll(")");
    }
};

pub const Lambda = struct {
    params: std.ArrayList([]const u8),
    body: std.ArrayList(Object),
    env: *Env,

    pub fn inspect(self: Lambda, writer: anytype) anyerror!void {
        try writer.writeAll("(lambda (");
        for (self.params.items, 0..) |param, i| {
            if (i > 0) {
                try writer.writeAll(" ");
            }
            try writer.writeAll(param);
        }
        try writer.writeAll(") ");

        try writer.writeAll("(");
        for (self.body.items, 0..) |expr, i| {
            if (i > 0) {
                try writer.writeAll(" ");
            }
            try expr.inspect(writer);
        }
        try writer.writeAll("))");
    }
};

pub const List = struct {
    list: std.ArrayList(Object),

    pub fn inspect(self: List, writer: anytype) !void {
        try writer.writeAll("(");
        for (self.list.items, 0..) |obj, i| {
            if (i > 0) {
                try writer.writeAll(" ");
            }
            try obj.inspect(writer);
        }
        try writer.writeAll(")");
    }
};
