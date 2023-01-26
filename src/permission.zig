const std = @import("std");

pub const Name = enum {
    read,
    print,
    edit_all,
    copy,
    edit,
};
