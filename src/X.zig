const std = @import("std");

const A = struct {
    another: *anyopaque,
};
const B = struct {
    another: ?*anyopaque,
};

test {
    var b = B{ .another = null };
    const any_b: *anyopaque = &b;

    const x = A{ .another = any_b };

    const z: *B = @ptrCast(*B, @alignCast(@alignOf(B), x.another));
    const zz: B = z.*;
    std.log.warn("{}", .{zz});
}