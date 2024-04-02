const std = @import("std");

const Env = @import("Env.zig");

pub const Object = union(enum(u8)) {
    Void: void,
    If: If,
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

    pub fn string(self: Object, writer: anytype) !void {
        return switch (self) {
            inline else => |x| x.string(writer),
        };
    }
};

pub const Void = struct {
    pub fn string(_: Void, writer: anytype) !void {
        try writer.writeAll("Void");
    }
};

pub const If = struct {
    pub fn string(_: If, writer: anytype) !void {
        try writer.writeAll("If");
    }
};

pub const Keyword = struct {
    value: []const u8,

    pub fn string(self: Keyword, writer: anytype) !void {
        try writer.writeAll(self.value);
    }
};

pub const BinaryOp = struct {
    value: []const u8,

    pub fn string(self: BinaryOp, writer: anytype) !void {
        try writer.writeAll(self.value);
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

pub const Bool = struct {
    pub fn string(self: Bool, writer: anytype) !void {
        try writer.print("{}", .{self.value});
    }
};

pub const String = struct {
    value: []const u8,

    pub fn string(self: String, writer: anytype) !void {
        try writer.writeAll(self.value);
    }
};

pub const Symbol = struct {
    value: []const u8,

    pub fn string(self: Symbol, writer: anytype) !void {
        try writer.writeAll(self.value);
    }
};

pub const ListData = struct {
    list: std.ArrayList(Object),

    pub fn string(self: ListData, writer: anytype) !void {
        _ = self;
        // write it after
        try writer.writeAll("ListData");
    }
};

pub const Lambda = struct {
    params: std.ArrayList(String),
    body: *std.ArrayList(Object),
    env: *Env,

    pub fn string(self: Lambda, writer: anytype) !void {
        _ = self;
        // write it after
        try writer.writeAll("Lambda");
    }
};

pub const List = struct {
    list: *std.ArrayList(Object),

    pub fn string(self: Lambda, writer: anytype) !void {
        _ = self;
        // write it after
        try writer.writeAll("List");
    }
};
