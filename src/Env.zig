const std = @import("std");

const Object = @import("Object.zig");

const Env = @This();

allocator: std.mem.Allocator,
parent: ?*Env,
vars: std.StringHashMap(Object.Object),

pub fn init(allocator: std.mem.Allocator) !Env {
    return .{
        .allocator = allocator,
        .parent = null,
        .vars = std.StringHashMap(Object.Object).init(allocator),
    };
}

pub fn get(self: Env, key: []const u8) ?Object.Object {
    var obj = self.vars.get(key);

    if (obj == null and self.parent != null) {
        obj = self.parent.?.get(key);
    }

    return obj;
}

pub fn set(self: *Env, key: []const u8, value: Object.Object) !void {
    try self.vars.put(key, value);
}

pub fn extend(self: Env, parent: *Env) !*Env {
    const env = try self.allocator.create(Env);
    env.* = .{
        .allocator = self.allocator,
        .parent = parent,
        .vars = std.StringHashMap(Object.Object).init(self.allocator),
    };

    return env;
}
