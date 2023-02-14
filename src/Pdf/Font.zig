const Self = @This();

pub const Font = union(enum) {
    named_font: NamedFont,
    ttc: Ttc,
    ttf: Ttf,
    type1: Type1,
};

pub const NamedFont = struct {
    const NamedFontSelf = @This();
    name: []const u8,
    encoding_name: ?[]const u8,
    pub fn init(name: []const u8, encoding_name: ?[]const u8) NamedFontSelf {
        return .{
            .name = name,
            .encoding_name = encoding_name,
        };
    }
};

pub const Ttc = struct {
    const TtcSelf = @This();
    file_path: []const u8,
    index: u32,
    embedding: bool,
    encoding_name: ?[]const u8,
    pub fn init(file_path: []const u8, index: u32, embedding: bool, encoding_name: ?[]const u8) TtcSelf {
        return .{
            .file_path = file_path,
            .index = index,
            .embedding = embedding,
            .encoding_name = encoding_name,
        };
    }
};

pub const Ttf = struct {
    const TtfSelf = @This();
    file_path: []const u8,
    embedding: bool,
    encoding_name: ?[]const u8,
    pub fn init(file_path: []const u8, embedding: bool, encoding_name: ?[]const u8) TtfSelf {
        return .{
            .file_path = file_path,
            .embedding = embedding,
            .encoding_name = encoding_name,
        };
    }
};

pub const Type1 = struct {
    const Type1Self = @This();
    arm_file_path: []const u8,
    data_file_path: []const u8,
    encoding_name: ?[]const u8,
    pub fn init(arm_file_path: []const u8, data_file_path: []const u8, encoding_name: ?[]const u8) Type1Self {
        return .{
            .arm_file_path = arm_file_path,
            .data_file_path = data_file_path,
            .encoding_name = encoding_name,
        };
    }
};

pub fn wrap(font: anytype) Font {
    return switch (@TypeOf(font)) {
        NamedFont => Font{ .named_font = font },
        Ttc => Font{ .ttc = font },
        Ttf => Font{ .ttf = font },
        Type1 => Font{ .type1 = font },
        else => @panic("unexpected"),
    };
}
