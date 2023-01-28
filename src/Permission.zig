const std = @import("std");

pub const PermissionName = enum {
    read,
    print,
    edit_all,
    copy,
    edit,
};
