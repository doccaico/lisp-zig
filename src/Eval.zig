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
            .String => |x| {
                return .{ .String = .{ .value = x.value } };
            },
            .Bool => |x| {
                return .{ .Bool = .{ .value = x.value } };
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
                                return error.InvalidTypesAddOperator;
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
                                return error.InvalidTypesAddOperator;
                            },
                        }
                    },
                    .String => |l| {
                        switch (right) {
                            .String,
                            => |r| {
                                const str = try std.fmt.allocPrint(allocator, "{s}{s}", .{ l.value, r.value });
                                return .{ .String = .{ .value = str } };
                            },
                            else => {
                                return error.InvalidTypesAddOperator;
                            },
                        }
                    },
                    else => {
                        return error.InvalidTypesAddOperator;
                    },
                }
            } else if (std.mem.eql(u8, "-", x.value)) {
                switch (left) {
                    .Integer => |l| {
                        switch (right) {
                            .Integer,
                            => |r| {
                                return .{ .Integer = .{ .value = l.value - r.value } };
                            },
                            .Float,
                            => |r| {
                                return .{ .Float = .{ .value = @as(f64, @floatFromInt(l.value)) - r.value } };
                            },
                            else => {
                                return error.InvalidTypesSubOperator;
                            },
                        }
                    },
                    .Float => |l| {
                        switch (right) {
                            .Integer,
                            => |r| {
                                return .{ .Float = .{ .value = l.value - @as(f64, @floatFromInt(r.value)) } };
                            },
                            .Float,
                            => |r| {
                                return .{ .Float = .{ .value = l.value - r.value } };
                            },
                            else => {
                                return error.InvalidTypesSubOperator;
                            },
                        }
                    },
                    else => {
                        return error.InvalidTypesSubOperator;
                    },
                }
            } else if (std.mem.eql(u8, "*", x.value)) {
                switch (left) {
                    .Integer => |l| {
                        switch (right) {
                            .Integer,
                            => |r| {
                                return .{ .Integer = .{ .value = l.value * r.value } };
                            },
                            .Float,
                            => |r| {
                                return .{ .Float = .{ .value = @as(f64, @floatFromInt(l.value)) * r.value } };
                            },
                            else => {
                                return error.InvalidTypesMulOperator;
                            },
                        }
                    },
                    .Float => |l| {
                        switch (right) {
                            .Integer,
                            => |r| {
                                return .{ .Float = .{ .value = l.value * @as(f64, @floatFromInt(r.value)) } };
                            },
                            .Float,
                            => |r| {
                                return .{ .Float = .{ .value = l.value * r.value } };
                            },
                            else => {
                                return error.InvalidTypesMulOperator;
                            },
                        }
                    },
                    else => {
                        return error.InvalidTypesMulOperator;
                    },
                }
            } else if (std.mem.eql(u8, "/", x.value)) {
                switch (left) {
                    .Integer => |l| {
                        switch (right) {
                            .Integer,
                            => |r| {
                                return .{ .Integer = .{ .value = @divTrunc(l.value, r.value) } };
                            },
                            .Float,
                            => |r| {
                                return .{ .Float = .{ .value = @divTrunc(@as(f64, @floatFromInt(l.value)), r.value) } };
                            },
                            else => {
                                return error.InvalidTypesDivOperator;
                            },
                        }
                    },
                    .Float => |l| {
                        switch (right) {
                            .Integer,
                            => |r| {
                                return .{ .Float = .{ .value = @divTrunc(l.value, @as(f64, @floatFromInt(r.value))) } };
                            },
                            .Float,
                            => |r| {
                                return .{ .Float = .{ .value = @divTrunc(l.value, r.value) } };
                            },
                            else => {
                                return error.InvalidTypesDivOperator;
                            },
                        }
                    },
                    else => {
                        return error.InvalidTypesDivOperator;
                    },
                }
            } else if (std.mem.eql(u8, "=", x.value)) {
                switch (left) {
                    .Integer => |l| {
                        switch (right) {
                            .Integer,
                            => |r| {
                                return .{ .Bool = .{ .value = l.value == r.value } };
                            },
                            else => {
                                return error.InvalidTypesEqOperator;
                            },
                        }
                    },
                    .Float => |l| {
                        switch (right) {
                            .Float,
                            => |r| {
                                return .{ .Bool = .{ .value = l.value == r.value } };
                            },
                            else => {
                                return error.InvalidTypesEqOperator;
                            },
                        }
                    },
                    .String => |l| {
                        switch (right) {
                            .String,
                            => |r| {
                                return .{ .Bool = .{ .value = std.mem.eql(u8, l.value, r.value) } };
                            },
                            else => {
                                return error.InvalidTypesEqOperator;
                            },
                        }
                    },
                    else => {
                        return error.InvalidTypesEqOperator;
                    },
                }
            } else if (std.mem.eql(u8, ">", x.value)) {
                switch (left) {
                    .Integer => |l| {
                        switch (right) {
                            .Integer,
                            => |r| {
                                return .{ .Bool = .{ .value = l.value > r.value } };
                            },
                            .Float,
                            => |r| {
                                return .{ .Bool = .{ .value = @as(f64, @floatFromInt(l.value)) > r.value } };
                            },
                            else => {
                                return error.InvalidTypesGreaterThanOperator;
                            },
                        }
                    },
                    .Float => |l| {
                        switch (right) {
                            .Integer,
                            => |r| {
                                return .{ .Bool = .{ .value = l.value > @as(f64, @floatFromInt(r.value)) } };
                            },
                            .Float,
                            => |r| {
                                return .{ .Bool = .{ .value = l.value > r.value } };
                            },
                            else => {
                                return error.InvalidTypesGreaterThanOperator;
                            },
                        }
                    },
                    .String => |l| {
                        switch (right) {
                            .String,
                            => |r| {
                                return .{ .Bool = .{ .value = std.mem.order(u8, l.value, r.value) == std.math.Order.gt } };
                            },
                            else => {
                                return error.InvalidTypesGreaterThanOperator;
                            },
                        }
                    },
                    else => {
                        return error.InvalidTypesGreaterThanOperator;
                    },
                }
            } else if (std.mem.eql(u8, "<", x.value)) {
                switch (left) {
                    .Integer => |l| {
                        switch (right) {
                            .Integer,
                            => |r| {
                                return .{ .Bool = .{ .value = l.value < r.value } };
                            },
                            .Float,
                            => |r| {
                                return .{ .Bool = .{ .value = @as(f64, @floatFromInt(l.value)) < r.value } };
                            },
                            else => {
                                return error.InvalidTypesLessThanOperator;
                            },
                        }
                    },
                    .Float => |l| {
                        switch (right) {
                            .Integer,
                            => |r| {
                                return .{ .Bool = .{ .value = l.value < @as(f64, @floatFromInt(r.value)) } };
                            },
                            .Float,
                            => |r| {
                                return .{ .Bool = .{ .value = l.value < r.value } };
                            },
                            else => {
                                return error.InvalidTypesLessThanOperator;
                            },
                        }
                    },
                    .String => |l| {
                        switch (right) {
                            .String,
                            => |r| {
                                return .{ .Bool = .{ .value = std.mem.order(u8, l.value, r.value) == std.math.Order.lt } };
                            },
                            else => {
                                return error.InvalidTypesLessThanOperator;
                            },
                        }
                    },
                    else => {
                        return error.InvalidTypesLessThanOperator;
                    },
                }
            } else if (std.mem.eql(u8, "%", x.value)) {
                switch (left) {
                    .Integer => |l| {
                        switch (right) {
                            .Integer,
                            => |r| {
                                return .{ .Integer = .{ .value = @mod(l.value, r.value) } };
                            },
                            .Float,
                            => |r| {
                                return .{ .Float = .{ .value = @mod(@as(f64, @floatFromInt(l.value)), r.value) } };
                            },
                            else => {
                                return error.InvalidTypesModuloOperator;
                            },
                        }
                    },
                    .Float => |l| {
                        switch (right) {
                            .Integer,
                            => |r| {
                                return .{ .Float = .{ .value = @mod(l.value, @as(f64, @floatFromInt(r.value))) } };
                            },
                            .Float,
                            => |r| {
                                return .{ .Float = .{ .value = @mod(l.value, r.value) } };
                            },
                            else => {
                                return error.InvalidTypesModuloOperator;
                            },
                        }
                    },
                    else => {
                        return error.InvalidTypesModuloOperator;
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

test "test_simple_sub" {
    const Test = struct {
        []const u8,
        Object.Object,
    };
    const tests = [_]Test{
        .{
            "(- 1 2)",
            .{ .Integer = .{ .value = -1 } },
        },
        .{
            "(- 1 0.5)",
            .{ .Float = .{ .value = 0.5 } },
        },
        .{
            "(- 3.5 2.5)",
            .{ .Float = .{ .value = 1.0 } },
        },
        .{
            "(- 2.5 1)",
            .{ .Float = .{ .value = 1.5 } },
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

test "test_simple_mul" {
    const Test = struct {
        []const u8,
        Object.Object,
    };
    const tests = [_]Test{
        .{
            "(* 1 2)",
            .{ .Integer = .{ .value = 2 } },
        },
        .{
            "(* 5 0.5)",
            .{ .Float = .{ .value = 2.5 } },
        },
        .{
            "(* 3.0 1.0)",
            .{ .Float = .{ .value = 3.0 } },
        },
        .{
            "(* 5.0 5)",
            .{ .Float = .{ .value = 25.0 } },
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

test "test_simple_div" {
    const Test = struct {
        []const u8,
        Object.Object,
    };
    const tests = [_]Test{
        .{
            "(/ 10 2)",
            .{ .Integer = .{ .value = 5 } },
        },
        .{
            "(/ 5 0.5)",
            .{ .Float = .{ .value = 10.0 } },
        },
        .{
            "(/ 3.0 1.0)",
            .{ .Float = .{ .value = 3.0 } },
        },
        .{
            "(/ 5.0 5)",
            .{ .Float = .{ .value = 1.0 } },
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

test "test_string_add" {
    const Test = struct {
        []const u8,
        []const u8,
    };
    const tests = [_]Test{
        .{
            "(+ \"Raleigh\" \"Durham\")",
            "RaleighDurham",
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], env);
        const expected = t[1];
        try std.testing.expect(std.mem.eql(u8, expected, actual.String.value));
    }
}

test "test_string_compare" {
    const Test = struct {
        []const u8,
        bool,
    };
    const tests = [_]Test{
        .{
            "(= \"Raleigh\" \"Durham\")",
            false,
        },
        .{
            "(= \"Raleigh\" \"Raleigh\")",
            true,
        },
        .{
            "(> \"Raleigh\" \"Durham\")",
            true,
        },
        .{
            "(< \"abcd\" \"abef\")",
            true,
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], env);
        const expected = t[1];
        try std.testing.expectEqual(expected, actual.Bool.value);
    }
}

test "test_string_with_spaces" {
    const Test = struct {
        []const u8,
        []const u8,
    };
    const tests = [_]Test{
        .{
            "(+ \"Raleigh \" \"Durham\")",
            "Raleigh Durham",
        },
        // TODO
        // .{
        //     \\(
        //     \\    (define fruits "apples mangoes bananas ")
        //     \\    (define vegetables "carrots broccoli")
        //     \\    (+ fruits vegetables)
        //     \\)
        //     ,
        //     "apples mangoes bananas carrots broccoli",
        // },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], env);
        const expected = t[1];
        try std.testing.expectEqualStrings(expected, actual.String.value);
    }
}

test "test_number_compare" {
    const Test = struct {
        []const u8,
        bool,
    };
    const tests = [_]Test{
        .{
            "(> 1 2)",
            false,
        },
        .{
            "(> 1 2.0)",
            false,
        },
        .{
            "(> 2.5 2.0)",
            true,
        },
        .{
            "(> 2.5 2)",
            true,
        },
        .{
            "(< 1 2)",
            true,
        },
        .{
            "(< 1 2.0)",
            true,
        },
        .{
            "(< 2.5 2.0)",
            false,
        },
        .{
            "(< 2.5 2)",
            false,
        },
        .{
            "(= 2 2)",
            true,
        },
        .{
            "(= 2 4)",
            false,
        },
        .{
            "(= 2.0 2.0)",
            true,
        },
        .{
            "(= 2.0 4.0)",
            false,
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], env);
        const expected = t[1];
        try std.testing.expectEqual(expected, actual.Bool.value);
    }
}

test "test_modulo" {
    const Test = struct {
        []const u8,
        Object.Object,
    };
    const tests = [_]Test{
        .{
            "(% 10 3)",
            .{ .Integer = .{ .value = 1 } },
        },
        .{
            "(% 10 3.0)",
            .{ .Float = .{ .value = 1.0 } },
        },
        .{
            "(% 10.0 3.0)",
            .{ .Float = .{ .value = 1.0 } },
        },
        .{
            "(% 10.0 3)",
            .{ .Float = .{ .value = 1.0 } },
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], env);
        const expected = t[1];
        try std.testing.expectEqual(expected, actual);
    }
}
