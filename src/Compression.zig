const std = @import("std");

pub const CompressionMode = enum {
    none,
    text,
    image,
    metadata,
    all,
};
