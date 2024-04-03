const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const print = std.debug.print;
const assert = std.debug.assert;
const expect = std.testing.expect;

pub fn main() !void {
    {
        const a = "abc";
        const b = "abc";

        const r = mem.order(u8, a, b);

        print("{any}\n", .{r == std.math.Order.eq});
    }

    {
        const a: f64 = 1.5;
        const b: f64 = 1.6;
        print("{any}\n", .{a == b});
    }

    {
        print("{s}\n", .{
            \\ abc
            \\ xyz
        });
    }

    {
        print("{d}\n", .{10 % 2});
        const a: f64 = 10.1;
        const b: f64 = 2.0;
        print("{d}\n", .{a % b});
        print("{any}\n", .{0.0999 == 0.099});
        print("{d:.2}\n", .{@mod(a, b)});
    }
    {
        const a: i64 = 10;
        const b: i64 = 3;
        const c: i64 = a % b;
        print("{d}\n", .{c});
        print("{any}\n", .{true and true});
        // print("{d:.2}\n", .{@mod(a, b)});
    }
}
