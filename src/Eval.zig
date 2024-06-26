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
                            .Lambda => {
                                var new_obj = .{ .List = .{ .list = new_list } };
                                return try eval_obj(allocator, &new_obj, current_env);
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
            } else if (std.mem.eql(u8, x.value, "print")) {
                return eval_print(allocator, list, env);
            } else if (std.mem.eql(u8, x.value, "map")) {
                return eval_map(allocator, list, env);
            } else if (std.mem.eql(u8, x.value, "filter")) {
                return eval_filter(allocator, list, env);
            } else if (std.mem.eql(u8, x.value, "reduce")) {
                return eval_reduce(allocator, list, env);
            } else if (std.mem.eql(u8, x.value, "range")) {
                return eval_range(allocator, list, env);
            } else if (std.mem.eql(u8, x.value, "car")) {
                return eval_car(allocator, list, env);
            } else if (std.mem.eql(u8, x.value, "cdr")) {
                return eval_cdr(allocator, list, env);
            } else if (std.mem.eql(u8, x.value, "length")) {
                return eval_length(allocator, list, env);
            } else if (std.mem.eql(u8, x.value, "null?")) {
                return eval_is_null(allocator, list, env);
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
            const name = blk: {
                switch (x.list.items[0]) {
                    .Symbol => |y| break :blk y,
                    else => return error.InvalidSymbolForDefine,
                }
            };
            // var params: Object.Object = .{ .List = .{ .list = undefined } };
            var params: Object.Object = .{ .List = .{ .list = std.ArrayList(Object.Object).init(allocator) } };
            try params.List.list.appendSlice(x.list.items[1..]);
            const body = list.items[2];
            var new_obj = std.ArrayList(Object.Object).init(allocator);
            try new_obj.append(.{ .Void = {} });
            try new_obj.append(params);
            try new_obj.append(body);
            const lambda = try eval_function_definition(allocator, new_obj, env);
            try env.set(name.value, lambda);
            return .{ .Void = {} };
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

    switch (lambda) {
        .Lambda => {
            if (lambda.Lambda.params.items.len != 1) {
                return error.InvalidNumberParamsForMapLambdaFunc;
            }
        },
        else => return error.NotALambdaWhileEvalMap,
    }
    const params = lambda.Lambda.params;
    const body = lambda.Lambda.body;
    const func_env = lambda.Lambda.env;

    const args = blk: {
        switch (arg_list) {
            .ListData => |x| break :blk x,
            else => return error.InvalidMapArgs,
        }
    };

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

fn eval_print(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    const stdout = std.io.getStdOut().writer();

    if (list.items.len != 2) {
        return error.InvalidNumberArgsForPrint;
    }
    var obj = try eval_obj(allocator, &list.items[1], env);
    try obj.inspect(stdout);

    return .{ .Void = {} };
}

fn eval_filter(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    if (list.items.len != 3) {
        return error.InvalidNumberArgsForFilter;
    }
    const lambda = try eval_obj(allocator, &list.items[1], env);
    const arg_list = try eval_obj(allocator, &list.items[2], env);

    switch (lambda) {
        .Lambda => {
            if (lambda.Lambda.params.items.len != 1) {
                return error.InvalidNumberParamsForFilterLambdaFunc;
            }
        },
        else => return error.NotALambdaWhileEvalFilter,
    }
    const params = lambda.Lambda.params;
    const body = lambda.Lambda.body;
    const func_env = lambda.Lambda.env;

    const args = blk: {
        switch (arg_list) {
            .ListData => |x| break :blk x,
            else => return error.InvalidFilterArgs,
        }
    };

    const func_param = params.items[0];
    var result_list = std.ArrayList(Object.Object).init(allocator);
    for (args.list.items) |*arg| {
        const val = try eval_obj(allocator, arg, env);
        var new_env = try env.extend(func_env);
        try new_env.set(func_param, val);
        const new_body = body;
        var new_obj = .{ .List = .{ .list = new_body } };
        const result_obj = try eval_obj(allocator, &new_obj, new_env);
        const result = blk: {
            switch (result_obj) {
                .Bool => |x| break :blk x,
                else => return error.InvalidFilterResult,
            }
        };
        if (result.value) {
            try result_list.append(val);
        }
    }

    return .{ .ListData = .{ .list = result_list } };
}

fn eval_reduce(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    if (list.items.len != 3) {
        return error.InvalidNumberArgsForReduce;
    }
    const lambda = try eval_obj(allocator, &list.items[1], env);
    const arg_list = try eval_obj(allocator, &list.items[2], env);

    switch (lambda) {
        .Lambda => |x| {
            if (x.params.items.len != 2) {
                return error.InvalidNumberParamsForReduceLambdaFunc;
            }
        },
        else => return error.NotALambdaWhileEvalReduce,
    }
    const params = lambda.Lambda.params;
    const body = lambda.Lambda.body;
    const func_env = lambda.Lambda.env;

    const args = blk: {
        switch (arg_list) {
            .ListData => |x| break :blk x,
            else => return error.InvalidReduceArgs,
        }
    };

    if (args.list.items.len < 2) {
        return error.InvalidNumberArgsForReduce;
    }

    const reduce_param1 = params.items[0];
    const reduce_param2 = params.items[1];
    var accumulator = try eval_obj(allocator, &args.list.items[0], env);
    for (args.list.items[1..]) |*arg| {
        var new_env = try env.extend(func_env);
        try new_env.set(reduce_param1, accumulator);

        const val = try eval_obj(allocator, arg, env);
        try new_env.set(reduce_param2, val);

        const new_body = body;
        var new_obj = .{ .List = .{ .list = new_body } };
        accumulator = try eval_obj(allocator, &new_obj, new_env);
    }
    return accumulator;
}

// punk
fn eval_range(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    if (list.items.len != 3 and list.items.len != 4) {
        return error.InvalidNumberArgsForRange;
    }

    const start_obj = try eval_obj(allocator, &list.items[1], env);
    const end_obj = try eval_obj(allocator, &list.items[2], env);
    var stride: i64 = 1;
    if (list.items.len == 4) {
        const stride_obj = try eval_obj(allocator, &list.items[3], env);
        stride = blk: {
            switch (stride_obj) {
                .Integer => |x| break :blk x.value,
                else => return error.InvalidStrideForRange,
            }
        };
    }

    const start = blk: {
        switch (start_obj) {
            .Integer => |x| break :blk x.value,
            else => return error.InvalidStartFroRange,
        }
    };
    const end = blk: {
        switch (end_obj) {
            .Integer => |x| break :blk x.value,
            else => return error.InvalidEndFroRange,
        }
    };

    var new_list = std.ArrayList(Object.Object).init(allocator);
    var i = start;
    while (i < end) : (i += stride) {
        try new_list.append(.{ .Integer = .{ .value = i } });
    }

    return .{ .ListData = .{ .list = new_list } };
}

fn eval_car(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    const l = try eval_obj(allocator, &list.items[1], env);
    return switch (l) {
        .ListData => |x| x.list.items[0],
        else => error.ArgIsNotList,
    };
}

fn eval_cdr(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    const l = try eval_obj(allocator, &list.items[1], env);
    var new_list = std.ArrayList(Object.Object).init(allocator);
    switch (l) {
        .ListData => |x| {
            for (x.list.items[1..]) |obj| {
                try new_list.append(obj);
            }
            return .{ .ListData = .{ .list = new_list } };
        },
        else => return error.ArgIsNotList,
    }
}

fn eval_length(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    const obj = try eval_obj(allocator, &list.items[1], env);
    switch (obj) {
        .List => |x| return .{ .Integer = .{ .value = @intCast(x.list.items.len) } },
        .ListData => |x| return .{ .Integer = .{ .value = @intCast(x.list.items.len) } },
        else => return error.ArgIsNotList,
    }
}

fn eval_is_null(allocator: std.mem.Allocator, list: std.ArrayList(Object.Object), env: *Env) !Object.Object {
    const obj = try eval_obj(allocator, &list.items[1], env);
    switch (obj) {
        .List => |x| return .{ .Bool = .{ .value = x.list.items.len == 0 } },
        .ListData => |x| return .{ .Bool = .{ .value = x.list.items.len == 0 } },
        else => return error.ArgIsNotList,
    }
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

test "test_filter" {
    const Test = struct {
        []const u8,
        Object.Object,
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var list = std.ArrayList(Object.Object).init(allocator);
    try list.append(.{ .Integer = .{ .value = 1 } });
    try list.append(.{ .Integer = .{ .value = 3 } });
    try list.append(.{ .Integer = .{ .value = 5 } });

    const tests = [_]Test{
        .{
            \\ (begin
            \\     (define odd (lambda (v) (= 1 (% v 2))))
            \\     (define l (list 1 2 3 4 5))
            \\     (filter odd l)
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

test "test_reduce" {
    const Test = struct {
        []const u8,
        Object.Object,
    };
    const tests = [_]Test{
        .{
            \\ (begin
            \\     (define add (lambda (a b) (+ a b)))
            \\     (define l (list 1 2 4 8 16 32))
            \\     (reduce add l )
            \\ )
            ,
            .{ .Integer = .{ .value = 63 } },
        },
        .{
            \\ (begin
            \\     (define odd (lambda (v) (= 1 (% v 2))))
            \\     (define l (list 1 2 3 4 5))
            \\     (reduce (lambda (x y) (or x y)) (map odd l))
            \\ )
            ,
            .{ .Bool = .{ .value = true } },
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

test "test_range_no_stride" {
    const Test = struct {
        []const u8,
        Object.Object,
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var list = std.ArrayList(Object.Object).init(allocator);
    try list.append(.{ .Integer = .{ .value = 0 } });
    try list.append(.{ .Integer = .{ .value = 1 } });
    try list.append(.{ .Integer = .{ .value = 2 } });
    try list.append(.{ .Integer = .{ .value = 3 } });
    try list.append(.{ .Integer = .{ .value = 4 } });
    try list.append(.{ .Integer = .{ .value = 5 } });

    const tests = [_]Test{
        .{
            "(range 0 6)",
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

test "test_range_with_stride" {
    const Test = struct {
        []const u8,
        Object.Object,
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var list = std.ArrayList(Object.Object).init(allocator);
    try list.append(.{ .Integer = .{ .value = 0 } });
    try list.append(.{ .Integer = .{ .value = 3 } });
    try list.append(.{ .Integer = .{ .value = 6 } });
    try list.append(.{ .Integer = .{ .value = 9 } });

    const tests = [_]Test{
        .{
            "(range 0 10 3)",
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

test "test_car" {
    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{
            \\ (begin
            \\     (car (list 1 2 3))
            \\ )
            ,
            1,
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

test "test_cdr" {
    const Test = struct {
        []const u8,
        Object.Object,
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var list = std.ArrayList(Object.Object).init(allocator);
    try list.append(.{ .Integer = .{ .value = 2 } });
    try list.append(.{ .Integer = .{ .value = 3 } });

    const tests = [_]Test{
        .{
            \\ (begin
            \\     (cdr (list 1 2 3))
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

test "test_length" {
    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{
            \\ (begin
            \\     (length (list 1 2 3))
            \\ )
            ,
            3,
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

test "test_is_null" {
    const Test = struct {
        []const u8,
        bool,
    };
    const tests = [_]Test{
        .{
            "(null? (list 1 2 3 4 5))",
            false,
        },
        .{
            "(null? (list))",
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

test "test_define_function" {
    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{
            \\ (begin
            \\     (define (add a b) (+ a b))
            \\     (add 1 2)
            \\ )
            ,
            3,
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

test "test_functions" {
    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{
            \\ (begin
            \\     (define fib (lambda (n) 
            \\         (if (< n 2) 1 
            \\             (+ (fib (- n 1)) 
            \\                 (fib (- n 2))))))
            \\     (fib 10)
            \\ )
            ,
            89,
        },
        .{
            \\ (begin
            \\     (define fact (lambda (n) (if (< n 1) 1 (* n (fact (- n 1))))))
            \\     (fact 5)
            \\ )
            ,
            120,
        },
        .{
            \\ (begin
            \\     (define (abs n) (if (< n 0) (* -1 n) n))
            \\     (abs -5)
            \\ )
            ,
            5,
        },
        .{
            \\ (begin
            \\     (define sum-n 
            \\        (lambda (n a) 
            \\           (if (= n 0) a 
            \\               (sum-n (- n 1) (+ n a)))))
            \\     (sum-n 500 0)
            \\ )
            ,
            125250,
        },
        .{
            \\ (begin
            \\     (define fact 
            \\         (lambda (n a) 
            \\           (if (= n 1) a 
            \\             (fact (- n 1) (* n a)))))
            \\             
            \\     (fact 10 1)
            \\ )
            ,
            3628800,
        },
        .{
            \\ (begin
            \\     (define add-n 
            \\        (lambda (n) 
            \\           (lambda (a) (+ n a))))
            \\     (define add-5 (add-n 5))
            \\     (add-5 10)
            \\ )
            ,
            15,
        },
        .{
            \\ (begin
            \\     (define fib
            \\       (lambda (n a b) 
            \\          (if (= n 0) a 
            \\            (if (= n 1) b 
            \\               (fib (- n 1) b (+ a b))))))
            \\       
            \\     (fib 10 0 1)
            \\ )
            ,
            55,
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

test "test_inline_lambda" {
    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{
            \\ (begin
            \\     ((lambda (x y) (+ x y)) 10 20)
            \\ )
            ,
            30,
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

test "test_sum_list_of_integers" {
    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{
            \\ (begin
            \\     (define sum-list 
            \\         (lambda (l) 
            \\             (if (null? l) 0 
            \\                 (+ (car l) (sum-list (cdr l))))))
            \\     (sum-list (list 1 2 3 4 5))
            \\ )
            ,
            15,
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

test "test_function_application" {
    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{
            \\ (begin
            \\     (define (double value) 
            \\         (* 2 value))
            \\     (define (apply-twice fn value) 
            \\         (fn (fn value)))
            \\ 
            \\     (apply-twice double 5)
            \\ )
            ,
            20,
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

test "test_begin_scope1" {
    const Test = struct {
        []const u8,
        Object.Object,
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var list = std.ArrayList(Object.Object).init(allocator);
    try list.append(.{ .Integer = .{ .value = 20 } });
    try list.append(.{ .Integer = .{ .value = 30 } });
    try list.append(.{ .Integer = .{ .value = 40 } });

    const tests = [_]Test{
        .{
            \\ (begin
            \\     (define a 10)
            \\     (define b 20)
            \\     (define c 30)
            \\     (begin
            \\         (define a 20)
            \\         (define b 30)
            \\         (define c 40)
            \\         (list a b c)
            \\     )
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

test "test_begin_scope2" {
    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{
            \\ (begin 
            \\     (define x 10)
            \\     (begin
            \\         (define x 20)
            \\         x 
            \\     )
            \\     x
            \\ )
            ,
            10,
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
