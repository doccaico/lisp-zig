const std = @import("std");

const Object = @import("Object.zig");

pub const Env = struct {
    parent: ?*Env,
    vars: std.StringHashMap(Object.Object),
};
