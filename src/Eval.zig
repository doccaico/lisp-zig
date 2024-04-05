const std = @import("std");

const Env = @import("Env.zig");
const Object = @import("Object.zig");
const Parser = @import("Parser.zig");

pub fn eval(allocator: std.mem.Allocator, program: []const u8, env: *Env) !Object.Object {
    var parsed_list = try Parser.parse(allocator, program);
    return try eval_obj(allocator, &parsed_list, env);
}

fn eval_obj(allocator: std.mem.Allocator, object: *Object.Object, env: *Env) anyerror!Object.Object {
    var current_obj = try allocator.create(Object.Object);
    current_obj.* = object.*;

    var current_env = env;

    while (true) {
        switch (current_obj.*) {
            .List => |x| {
                const head = x.list.items[0];
                switch (head) {
                    .BinaryOp => {
                        return eval_binary_op(allocator, x.list, current_env);
                    },
                    .Keyword => {
                        return eval_keyword(allocator, x.list, current_env);
                    },
                    .If => {
                        if (x.list.items.len != 4) {
                            return error.InvalidNumberArgsForIfStatement;
                        }

                        const cond_obj = try eval_obj(allocator, &x.list.items[1], current_env);
                        var cond: Object.Bool = undefined;
                        switch (cond_obj) {
                            .Bool => |y| cond = y,
                            else => return error.ConditionMustBeBoolean,
                        }

                        if (cond.value) {
                            current_obj = try allocator.create(Object.Object);
                            current_obj.* = x.list.items[2];
                        } else {
                            current_obj = try allocator.create(Object.Object);
                            current_obj.* = x.list.items[3];
                        }
                        continue;
                    },
                    .Lambda => |y| {
                        const new_env = try env.extend(y.env);
                        for (y.params.items, 0..) |param, i| {
                            const val = try eval_obj(allocator, &x.list.items[i + 1], current_env);
                            try new_env.set(param, val);
                        }

                        const new_obj = try allocator.create(Object.Object);
                        new_obj.* = .{ .List = .{ .list = y.body } };
                        current_obj = new_obj;

                        current_env = new_env;

                        continue;
                    },
                    .Symbol => |y| {
                        const sym = current_env.get(y.value) orelse return error.UnboundSymbol;

                        switch (sym) {
                            .Integer => |z| return .{ .Integer = .{ .value = z.value } },
                            .String => |z| return .{ .String = .{ .value = z.value } },
                            .Lambda => |z| {
                                const new_env = try env.extend(z.env);

                                for (z.params.items, 0..) |param, i| {
                                    const val = try eval_obj(allocator, &x.list.items[i + 1], current_env);
                                    try new_env.set(param, val);
                                }
                                const new_obj = try allocator.create(Object.Object);
                                new_obj.* = .{ .List = .{ .list = z.body } };
                                current_obj = new_obj;

                                current_env = new_env;

                                continue;
                            },
                            else => return error.NotALambda,
                        }
                    },
                    else => {
                        var new_list = std.ArrayList(Object.Object).init(allocator);
                        for (x.list.items) |*obj| {
                            const result = try eval_obj(allocator, obj, env);
                            switch (result) {
                                .Void => {},
                                else => try new_list.append(result),
                            }
                        }
                        switch (new_list.items[0]) {
                            .Lambda => |y| {
                                _ = y;
                                return error.Todo;
                            },
                            else => return .{ .List = .{ .list = new_list } },
                        }
                    },
                }
            },
            .Void => {
                return .{ .Void = {} };
            },
            .Symbol => |x| {
                return try eval_symbol(x.value, current_env);
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
            .ListData => |x| {
                return .{ .ListData = .{ .list = x.list } };
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

fn eval_binary_op(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    if (list.items.len != 3) {
        return error.InvalidNumberArgsForInfixOperator;
    }
    const operator = list.items[0];
    const left = try eval_obj(allocator, &list.items[1], env);
    const right = try eval_obj(allocator, &list.items[2], env);

    switch (operator) {
        .BinaryOp => |x| {
            if (std.mem.eql(u8, x.value, "+")) {
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
            } else if (std.mem.eql(u8, x.value, "-")) {
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
            } else if (std.mem.eql(u8, x.value, "*")) {
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
            } else if (std.mem.eql(u8, x.value, "/")) {
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
            } else if (std.mem.eql(u8, x.value, "=")) {
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
            } else if (std.mem.eql(u8, x.value, ">")) {
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
            } else if (std.mem.eql(u8, x.value, "<")) {
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
            } else if (std.mem.eql(u8, x.value, "%")) {
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
            } else if (std.mem.eql(u8, x.value, "!=")) {
                switch (left) {
                    .Integer => |l| {
                        switch (right) {
                            .Integer,
                            => |r| {
                                return .{ .Bool = .{ .value = l.value != r.value } };
                            },
                            .Float,
                            => |r| {
                                return .{ .Bool = .{ .value = @as(f64, @floatFromInt(l.value)) != r.value } };
                            },
                            else => {
                                return error.InvalidTypesNotEqOperator;
                            },
                        }
                    },
                    .Float => |l| {
                        switch (right) {
                            .Float,
                            => |r| {
                                return .{ .Bool = .{ .value = l.value != r.value } };
                            },
                            .Integer,
                            => |r| {
                                return .{ .Bool = .{ .value = l.value != @as(f64, @floatFromInt(r.value)) } };
                            },
                            else => {
                                return error.InvalidTypesNotEqOperator;
                            },
                        }
                    },
                    .String => |l| {
                        switch (right) {
                            .String,
                            => |r| {
                                return .{ .Bool = .{ .value = std.mem.order(u8, l.value, r.value) != std.math.Order.eq } };
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
            } else if (std.mem.eql(u8, x.value, "and")) {
                switch (left) {
                    .Bool => |l| {
                        switch (right) {
                            .Bool,
                            => |r| {
                                return .{ .Bool = .{ .value = l.value and r.value } };
                            },
                            else => {
                                return error.InvalidTypesAndOperator;
                            },
                        }
                    },
                    else => {
                        return error.InvalidTypesAndOperator;
                    },
                }
            } else if (std.mem.eql(u8, x.value, "or")) {
                switch (left) {
                    .Bool => |l| {
                        switch (right) {
                            .Bool,
                            => |r| {
                                return .{ .Bool = .{ .value = l.value or r.value } };
                            },
                            else => {
                                return error.InvalidTypesOrOperator;
                            },
                        }
                    },
                    else => {
                        return error.InvalidTypesOrOperator;
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

fn eval_keyword(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    const head = list.items[0];
    switch (head) {
        .Keyword => |x| {
            if (std.mem.eql(u8, x.value, "define")) {
                return eval_define(allocator, list, env);
            } else if (std.mem.eql(u8, x.value, "lambda")) {
                return eval_function_definition(allocator, list, env);
            } else if (std.mem.eql(u8, x.value, "begin")) {
                return eval_begin(allocator, list, env);
            } else if (std.mem.eql(u8, x.value, "list")) {
                return eval_list_data(allocator, list, env);
            } else if (std.mem.eql(u8, x.value, "let")) {
                return eval_let(allocator, list, env);
            } else if (std.mem.eql(u8, x.value, "map")) {
                return eval_map(allocator, list, env);
            } else if (std.mem.eql(u8, x.value, "print")) {
                return eval_print_list(allocator, list, env);
            } else {
                return error.UnknownKeyword;
            }
        },
        else => {
            return error.InvalidKeyword;
        },
    }
}

fn eval_define(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    if (list.items.len != 3) {
        return error.InvalidNumberArgsForDefine;
    }

    const sym = switch (list.items[1]) {
        .Symbol => |x| x,
        .List => |x| {
            // TODO
            _ = x;
            return error.Todo;
        },
        else => return error.InvalidDefine,
    };
    const val = try eval_obj(allocator, &list.items[2], env);

    try env.set(sym.value, val);

    return .{ .Void = {} };
}

fn eval_function_definition(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    const params = blk: {
        switch (list.items[1]) {
            .List => |x| {
                var params = std.ArrayList([]const u8).init(allocator);
                for (x.list.items) |param| {
                    switch (param) {
                        .Symbol => |y| try params.append(y.value),
                        else => return error.InvalidLambdaParameter,
                    }
                }
                break :blk params;
            },
            else => return error.InvalidLambda,
        }
    };

    const body = blk: {
        switch (list.items[2]) {
            .List => |x| break :blk x.list,
            else => return error.InvalidLambda,
        }
    };

    return .{ .Lambda = .{ .params = params, .body = body, .env = env } };
}

fn eval_symbol(sym: []const u8, env: *Env) !Object.Object {
    if (std.mem.eql(u8, sym, "#t")) {
        return .{ .Bool = .{ .value = true } };
    } else if (std.mem.eql(u8, sym, "#f")) {
        return .{ .Bool = .{ .value = false } };
    } else if (std.mem.eql(u8, sym, "#nil")) {
        return .{ .Void = {} };
    }

    return env.get(sym) orelse error.UnboundSymbol;
}

fn eval_begin(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    var result: Object.Object = .{ .Void = {} };
    const new_env = try env.extend(env);
    for (list.items[1..]) |*obj| {
        result = try eval_obj(allocator, obj, new_env);
    }

    return result;
}

fn eval_list_data(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    var new_list = std.ArrayList(Object.Object).init(allocator);
    for (list.items[1..]) |*obj| {
        try new_list.append(try eval_obj(allocator, obj, env));
    }
    return .{ .ListData = .{ .list = new_list } };
}

fn eval_let(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    var result: Object.Object = .{ .Void = {} };
    var bindings_env = try Env.init(allocator);

    if (list.items.len < 3) {
        return error.InvalidNumberArgsForLet;
    }

    const bindings = blk: {
        switch (list.items[1]) {
            .List => |x| break :blk x,
            else => return error.InvalidBindingsForLet,
        }
    };

    for (bindings.list.items) |binding| {
        const b = blk: {
            switch (binding) {
                .List => |x| break :blk x,
                else => return error.InvalidBindingsForLet,
            }
        };
        if (b.list.items.len != 2) {
            return error.InvalidBindingsForLet;
        }
        const key = blk: {
            switch (b.list.items[0]) {
                .Symbol => |x| break :blk x,
                else => return error.InvalidBindingsForLet,
            }
        };
        const value = try eval_obj(allocator, &b.list.items[1], env);
        try bindings_env.set(key.value, value);
    }

    var new_env = try env.extend(env);
    try new_env.update(&bindings_env);

    for (list.items[2..]) |*obj| {
        result = try eval_obj(allocator, obj, new_env);
    }

    return result;
}

fn eval_map(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    if (list.items.len != 3) {
        return error.InvalidNumberArgsForMap;
    }
    const lambda = try eval_obj(allocator, &list.items[1], env);
    const arg_list = try eval_obj(allocator, &list.items[2], env);

    if (lambda.Lambda.params.items.len != 1) {
        return error.InvalidNumberParamsForMapLambdaFunc;
    }
    switch (lambda) {
        .Lambda => {},
        else => return error.NotALambdaWhileEvalMap,
    }

    const args = blk: {
        switch (arg_list) {
            .ListData => |x| break :blk x,
            else => return error.NotALambdaWhileEvalMap,
        }
    };
    const params = lambda.Lambda.params;
    const body = lambda.Lambda.body;
    const func_env = lambda.Lambda.env;

    const func_param = params.items[0];
    var result_list = std.ArrayList(Object.Object).init(allocator);
    for (args.list.items) |*arg| {
        const val = try eval_obj(allocator, arg, env);
        var new_env = try env.extend(func_env);
        try new_env.set(func_param, val);
        const new_body = body;
        var new_obj = .{ .List = .{ .list = new_body } };
        const result = try eval_obj(allocator, &new_obj, new_env);
        try result_list.append(result);
    }

    return .{ .ListData = .{ .list = result_list } };
}

fn eval_print_list(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    const stdout = std.io.getStdOut().writer();

    if (list.items.len != 2) {
        return error.InvalidNumberArgsForPrint;
    }
    var obj = try eval_obj(allocator, &list.items[1], env);
    try obj.inspect(stdout);

    return .{ .Void = {} };
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

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
        const expected = t[1];
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

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
        const expected = t[1];
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

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
        const expected = t[1];
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

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
        const expected = t[1];
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

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
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
        .{
            "(!= \"Raleigh\" \"Durham\")",
            true,
        },
        .{
            "(!= \"abcd\" \"abcd\")",
            false,
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
        const expected = t[1];
        try std.testing.expectEqual(expected, actual.Bool.value);
    }
}

test "test_string_with_spaces1" {
    const Test = struct {
        []const u8,
        []const u8,
    };
    const tests = [_]Test{
        .{
            "(+ \"Raleigh \" \"Durham\")",
            "Raleigh Durham",
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
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
        .{
            "(!= 2 2)",
            false,
        },
        .{
            "(!= 2 2.0)",
            false,
        },
        .{
            "(!= 2.0 4.0)",
            true,
        },
        .{
            "(!= 2.0 4)",
            true,
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
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

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
        const expected = t[1];
        try std.testing.expectEqual(expected, actual);
    }
}

test "test_and_or" {
    const Test = struct {
        []const u8,
        bool,
    };
    const tests = [_]Test{
        .{
            "(and (= 1 1) (= 2 2))",
            true,
        },
        .{
            "(and (= 1 1) (= 1 2)",
            false,
        },
        .{
            "(or (= 1 1) (= 1 2))",
            true,
        },
        .{
            "(or (= 1 2) (= 1 2)",
            false,
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
        const expected = t[1];
        try std.testing.expectEqual(expected, actual.Bool.value);
    }
}

test "test_define" {
    const Test = struct {
        []const u8,
        Object.Object,
    };
    const tests = [_]Test{
        .{
            "(define foobar 1)",
            .{ .Void = {} },
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
        const expected = t[1];
        try std.testing.expectEqual(expected, actual);
    }
}

test "test_string_with_spaces2" {
    const Test = struct {
        []const u8,
        []const u8,
    };
    const tests = [_]Test{
        .{
            \\(
            \\    (define fruits "apples mangoes bananas ")
            \\    (define vegetables "carrots broccoli")
            \\    (+ fruits vegetables)
            \\)
            ,
            "apples mangoes bananas carrots broccoli",
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
        const expected = t[1];
        try std.testing.expectEqualStrings(expected, actual.List.list.items[0].String.value);
    }
}

test "test_if" {
    const Test = struct {
        []const u8,
        []const u8,
    };
    const tests = [_]Test{
        .{
            \\ (if (> 2 1) "foo" "bar")
            ,
            "foo",
        },
        .{
            \\ (if (< 2 1) "foo" "bar")
            ,
            "bar",
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
        const expected = t[1];
        try std.testing.expectEqualStrings(expected, actual.String.value);
    }
}

test "test_lambda" {
    const Test = struct {
        []const u8,
        Object.Object,
    };
    const tests = [_]Test{
        .{
            \\ (
            \\     (define add (lambda (a b) (+ a b)))
            \\     (add 1 2)
            \\ )
            ,
            .{ .Integer = .{ .value = 3 } },
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
        const expected = t[1];
        try std.testing.expectEqual(expected, actual.List.list.items[0]);
    }
}

test "test_begin" {
    const Test = struct {
        []const u8,
        Object.Object,
    };
    const tests = [_]Test{
        .{
            \\ (begin
            \\     (define r 10)
            \\     (define pi 314)
            \\     (* pi (* r r))
            \\ );
            ,
            .{ .Integer = .{ .value = 314 * 10 * 10 } },
        },
        .{
            \\ (begin
            \\     (define r 5.0)
            \\     (define pi 3.14)
            \\     (* pi (* r r))
            \\ );
            ,
            .{ .Float = .{ .value = 3.14 * 5.0 * 5.0 } },
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
        const expected = t[1];
        try std.testing.expectEqual(expected, actual);
    }
}

test "test_list_data" {
    const Test = struct {
        []const u8,
        Object.Object,
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var list = std.ArrayList(Object.Object).init(allocator);
    try list.append(.{ .Integer = .{ .value = 1 } });
    try list.append(.{ .Integer = .{ .value = 2 } });
    try list.append(.{ .Integer = .{ .value = 3 } });

    const tests = [_]Test{
        .{
            "(list 1 2 3)",
            .{ .ListData = .{ .list = list } },
        },
    };

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
        const expected = t[1];
        try std.testing.expectEqualDeep(expected, actual);
    }
}

test "test_let" {
    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{
            \\ (begin
            \\     (let ((a 1) (b 2))
            \\         (+ a b)
            \\     )
            \\ )
            ,
            3,
        },
        .{
            \\ (begin
            \\     (define a 100)
            \\     (let ((a 1) (b 2))
            \\         (+ a b)
            \\     )
            \\     a
            \\ )
            ,
            100,
        },
        .{
            \\ (begin
            \\     (let ((x 2) (y 3))
            \\         (let ((x 7) (z (+ x y)))
            \\             (* z x)
            \\     )
            \\ )
            ,
            35,
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
        const expected = t[1];
        try std.testing.expectEqual(expected, actual.Integer.value);
    }
}

test "test_map" {
    const Test = struct {
        []const u8,
        Object.Object,
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var list = std.ArrayList(Object.Object).init(allocator);
    try list.append(.{ .Integer = .{ .value = 1 } });
    try list.append(.{ .Integer = .{ .value = 4 } });
    try list.append(.{ .Integer = .{ .value = 9 } });
    try list.append(.{ .Integer = .{ .value = 16 } });
    try list.append(.{ .Integer = .{ .value = 25 } });

    const tests = [_]Test{
        .{
            \\ (begin
            \\     (define sqr (lambda (r) (* r r)))
            \\     (define l (list 1 2 3 4 5))
            \\     (map sqr l)
            \\ )
            ,
            .{ .ListData = .{ .list = list } },
        },
    };

    var env = try Env.init(allocator);

    for (tests) |t| {
        const actual = try eval(allocator, t[0], &env);
        const expected = t[1];
        try std.testing.expectEqualDeep(expected, actual);
    }
}
