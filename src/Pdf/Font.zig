const Self = @This();

pub const FontFace = union(enum) {
    named_font: NamedFont,
    ttc: Ttc,
    ttf: Ttf,
};

pub const NamedFont = struct {
    const NamedFontSelf = @This();
    family: []const u8,
    name: []const u8,
    encoding_name: ?[]const u8,
    pub fn init(family: []const u8, name: []const u8, encoding_name: ?[]const u8) NamedFontSelf {
        return .{
            .family = family,
            .name = name,
            .encoding_name = encoding_name,
        };
    }
};

pub const Ttc = struct {
    const TtcSelf = @This();
    family: []const u8,
    file_path: []const u8,
    index: u32,
    embedding: bool,
    encoding_name: ?[]const u8,
    pub fn init(family: []const u8, file_path: []const u8, index: u32, embedding: bool, encoding_name: ?[]const u8) TtcSelf {
        return .{
            .family = family,
            .file_path = file_path,
            .index = index,
            .embedding = embedding,
            .encoding_name = encoding_name,
        };
    }
};

pub const Ttf = struct {
    const TtfSelf = @This();
    family: []const u8,
    file_path: []const u8,
    embedding: bool,
    encoding_name: ?[]const u8,
    pub fn init(family: []const u8, file_path: []const u8, embedding: bool, encoding_name: ?[]const u8) TtfSelf {
        return .{
            .family = family,
            .file_path = file_path,
            .embedding = embedding,
            .encoding_name = encoding_name,
        };
    }
};

pub fn wrap(font: anytype) FontFace {
    return switch (@TypeOf(font)) {
        NamedFont => FontFace{ .named_font = font },
        Ttc => FontFace{ .ttc = font },
        Ttf => FontFace{ .ttf = font },
        else => @panic("unexpected"),
    };
}
