const std = @import("std");

pub const Mode = enum {
    none,
    text,
    image,
    metadata,
    all,
};
