const std = @import("std");

pub fn generate(comptime T: type) T {
    var rand = std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp()));

    return rand.random().int(T);
}
