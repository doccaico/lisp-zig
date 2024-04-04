const std = @import("std");

const Object = @import("Object.zig");

const Env = @This();

parent: ?*Env,
vars: std.StringHashMap(Object.Object),

pub fn init(allocator: std.mem.Allocator) !*Env {
    const env = try allocator.create(Env);
    env.* = .{
        .parent = null,
        .vars = std.StringHashMap(Object.Object).init(allocator),
    };
    return env;
}

pub fn get(self: *Env, key: []const u8) ?Object.Object {
    return self.vars.get(key);
}

pub fn set(self: *Env, key: []const u8, value: Object.Object) !void {
    try self.vars.put(key, value);
}
