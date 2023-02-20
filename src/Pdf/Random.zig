const std = @import("std");

pub fn generate(comptime T: type) T {
    const static = struct {
        var rand = std.rand.DefaultPrng.init(0);
    };

    return static.rand.random().int(T);
}

test {
    const one = generate(u32);
    const two = generate(u32);

    try std.testing.expect(one != two);
}