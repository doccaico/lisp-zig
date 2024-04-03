const std = @import("std");

const Env = @import("Env.zig");
const Object = @import("Object.zig");
const Parser = @import("Parser.zig");

pub fn eval(allocator: std.mem.Allocator, program: []const u8, env: *Env) !Object.Object {
    var parsed_list = try Parser.parse(allocator, program);
    return try eval_obj(allocator, &parsed_list, env);
}

fn eval_obj(allocator: std.mem.Allocator, obj: *Object.Object, env: *Env) !Object.Object {
    const current_obj = try allocator.create(Object.Object);
    current_obj.* = obj.*;
    const current_env = try allocator.create(Env);
    current_env.* = env.*;

    while (true) {
        switch (current_obj.*) {
            .List => |x| {
                const head = x.list.items[0];
                switch (head) {
                    .BinaryOp => {
                        return eval_binary_op(allocator, x.list, current_env);
                    },
                    else => {},
                }
            },
            .Integer => |x| {
                return .{ .Integer = .{ .value = x.value } };
            },
            .Float => |x| {
                return .{ .Float = .{ .value = x.value } };
            },
            else => {
                return error.InvalidObject;
            },
        }
    }

    // const integer_obj = try allocator.create(Object.Integer);
    // integer_obj.value = 3;
    // const integer_obj: Object.Integer = .{ .value = 3 };
    // const new_obj = try allocator.create(Object.Object);
    // new_obj.* = .{ .Integer = integer_obj };
    // return new_obj;

    return .{ .Integer = .{ .value = -256 } };
}

fn eval_binary_op(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) anyerror!Object.Object {
    if (list.items.len != 3) {
        return error.InvalidNumberForInfixOperator;
    }
    const operator = list.items[0];
    const left = try eval_obj(allocator, &list.items[1], env);
    const right = try eval_obj(allocator, &list.items[2], env);

    switch (operator) {
        .BinaryOp => |x| {
            if (std.mem.eql(u8, "+", x.value)) {
                switch (left) {
                    .Integer => |l| {
                        switch (right) {
                            .Integer,
                            => |r| {
                                return .{ .Integer = .{ .value = l.value + r.value } };
                            },
                            .Float,
                            => |r| {
                                return .{ .Float = .{ .value = @as(f64, @floatFromInt(l.value)) + r.value } };
                            },
                            else => {
                                return error.InvalidTypesPlusOperator;
                            },
                        }
                    },
                    .Float => |l| {
                        switch (right) {
                            .Integer,
                            => |r| {
                                return .{ .Float = .{ .value = l.value + @as(f64, @floatFromInt(r.value)) } };
                            },
                            .Float,
                            => |r| {
                                return .{ .Float = .{ .value = l.value + r.value } };
                            },
                            else => {
                                return error.InvalidTypesPlusOperator;
                            },
                        }
                    },
                    else => {
                        return error.InvalidTypesPlusOperator;
                    },
                }
            }
        },
        else => {
            return error.OperatorIsNotSymbol;
        },
    }
    return .{ .Integer = .{ .value = -256 } };
}

test "test_simple_add" {
    const Test = struct {
        []const u8,
        Object.Object,
    };
    const tests = [_]Test{
        .{
            "(+ 1 2)",
            .{ .Integer = .{ .value = 3 } },
        },
        .{
            "(+ 1 2.5)",
            .{ .Float = .{ .value = 3.5 } },
        },
        .{
            "(+ 2.5 2.5)",
            .{ .Float = .{ .value = 5.0 } },
        },
        .{
            "(+ 2.5 1)",
            .{ .Float = .{ .value = 3.5 } },
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], env);
        const expected: Object.Object = t[1];
        try std.testing.expectEqual(expected, actual);
    }
}
