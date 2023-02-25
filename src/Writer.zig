const Self = @This();
const std = @import("std");
const c = @cImport({
    @cInclude("hpdf.h");
});
const grid = @import("grid.zig");
const Alignment = @import("Pdf/Alignment.zig");
const Border = @import("Pdf/Border.zig");
const Color = @import("Pdf/Color.zig");
const CompressionMode = @import("Compression.zig").CompressionMode;
const Container = @import("Pdf/Container.zig");
const Date = @import("Date.zig");
const Default = @import("Default.zig");
const Encode = @import("Encode.zig");
const EncryptionMode = @import("Encryption.zig").EncryptionMode;
const Font = @import("Pdf/Font.zig");
const Measure = @import("Measure.zig");
const Padding = @import("Pdf/Padding.zig");
const Page = @import("Pdf/Page.zig");
const Pdf = @import("Pdf.zig");
const PermissionName = @import("Permission.zig").PermissionName;
const Rect = @import("Pdf/Rect.zig");
const Rgb = @import("Pdf/Rgb.zig");
const Size = @import("Pdf/Size.zig");

allocator: std.mem.Allocator,
content_frame_map: std.AutoHashMap(u32, Rect),
font_map: std.StringHashMap(Font.NamedFont),
is_debug: bool,
pdf: Pdf,

pub fn init(allocator: std.mem.Allocator, pdf: Pdf, is_debug: bool) Self {
    return .{
        .allocator = allocator,
        .content_frame_map = std.AutoHashMap(u32, Rect).init(allocator),
        .font_map = std.StringHashMap(Font.NamedFont).init(allocator),
        .is_debug = is_debug,
        .pdf = pdf,
    };
}

pub fn deinit(self: *Self) void {
    self.content_frame_map.deinit();
    self.font_map.deinit();
}

pub fn save(self: *Self, file_name: []const u8) !void {
    const hpdf = c.HPDF_New(errorEandler, null);
    defer c.HPDF_Free(hpdf);

    self.setPdfAttributes(hpdf);

    if (self.pdf.fonts) |fonts| {
        for (fonts) |font| {
            const named_font = self.loadFont(hpdf, font);
            try self.font_map.put(named_font.family, named_font);
        }
    }

    for (self.pdf.pages) |page| {
        const hpage = c.HPDF_AddPage(hpdf);

        try self.renderPage(hpdf, hpage, page);
    }

    _ = c.HPDF_SaveToFile(hpdf, file_name.ptr);
}

fn setPdfAttributes(self: Self, hpdf: c.HPDF_Doc) void {
    const date = Date.now();
    const hdate = c.HPDF_Date{ .year = date.year, .month = date.month, .day = date.day, .hour = date.hours, .minutes = date.minutes, .seconds = date.seconds, .ind = ' ', .off_hour = 0, .off_minutes = 0 };
    _ = c.HPDF_SetInfoDateAttr(hpdf, c.HPDF_INFO_CREATION_DATE, hdate);
    _ = c.HPDF_SetInfoDateAttr(hpdf, c.HPDF_INFO_MOD_DATE, hdate);

    _ = c.HPDF_UseJPFonts(hpdf);
    _ = c.HPDF_UseJPEncodings(hpdf);

    if (self.pdf.author) |author| {
        _ = c.HPDF_SetInfoAttr(hpdf, c.HPDF_INFO_AUTHOR, author.ptr);
    }

    if (self.pdf.creator) |creator| {
        _ = c.HPDF_SetInfoAttr(hpdf, c.HPDF_INFO_CREATOR, creator.ptr);
    }

    if (self.pdf.title) |title| {
        _ = c.HPDF_SetInfoAttr(hpdf, c.HPDF_INFO_TITLE, title.ptr);
    }

    if (self.pdf.subject) |subject| {
        _ = c.HPDF_SetInfoAttr(hpdf, c.HPDF_INFO_SUBJECT, subject.ptr);
    }

    if (self.pdf.compression_mode) |compression_mode| {
        const hcompression_mode: c.HPDF_UINT = switch (compression_mode) {
            CompressionMode.all => c.HPDF_COMP_ALL,
            CompressionMode.image => c.HPDF_COMP_IMAGE,
            CompressionMode.text => c.HPDF_COMP_TEXT,
            CompressionMode.metadata => c.HPDF_COMP_METADATA,
            else => c.HPDF_COMP_NONE,
        };
        _ = c.HPDF_SetCompressionMode(hpdf, hcompression_mode);
    }

    if (self.pdf.owner_password) |owner_password| {
        if (self.pdf.user_password) |user_password| {
            _ = c.HPDF_SetPassword(hpdf, owner_password.ptr, user_password.ptr);
        } else {
            _ = c.HPDF_SetPassword(hpdf, owner_password.ptr, null);
        }

        if (self.pdf.encryption_mode) |encryption_mode| {
            const hencryption: c.HPDF_UINT = switch (encryption_mode) {
                EncryptionMode.Revision2 => c.HPDF_ENCRYPT_R2,
                EncryptionMode.Revision3 => c.HPDF_ENCRYPT_R3,
            };
            _ = c.HPDF_SetEncryptionMode(hpdf, hencryption, self.pdf.encryption_length orelse 5);
        }
    }

    if (self.pdf.permission_names) |_| {
        var hpermission: c.HPDF_UINT = 0;
        for (self.pdf.permission_names.?) |permission_name| {
            switch (permission_name) {
                PermissionName.read => {
                    hpermission |= c.HPDF_ENABLE_READ;
                },
                PermissionName.print => {
                    hpermission |= c.HPDF_ENABLE_PRINT;
                },
                PermissionName.edit_all => {
                    hpermission |= c.HPDF_ENABLE_EDIT_ALL;
                },
                PermissionName.copy => {
                    hpermission |= c.HPDF_ENABLE_COPY;
                },
                PermissionName.edit => {
                    hpermission |= c.HPDF_ENABLE_EDIT;
                },
            }
        }
        _ = c.HPDF_SetPermission(hpdf, hpermission);
    }
}

fn loadFont(self: Self, hpdf: c.HPDF_Doc, font: Font.FontFace) Font.NamedFont {
    _ = self;
    switch (font) {
        .named_font => {
            const named_font = font.named_font;
            
            return Font.NamedFont.init(named_font.family, named_font.name, named_font.encoding_name);
        },
        .ttc => {
            const ttc = font.ttc;
            const ptr = c.HPDF_LoadTTFontFromFile2(hpdf, ttc.file_path.ptr, ttc.index, if (ttc.embedding) c.HPDF_TRUE else c.HPDF_FALSE);
            const font_name = std.mem.sliceTo(ptr, 0);
            
            return Font.NamedFont.init(ttc.family, font_name, ttc.encoding_name);
        },
        .ttf => {
            const ttf = font.ttf;
            const ptr = c.HPDF_LoadTTFontFromFile(hpdf, ttf.file_path.ptr, if (ttf.embedding) c.HPDF_TRUE else c.HPDF_FALSE);
            const font_name = std.mem.sliceTo(ptr, 0);

            return Font.NamedFont.init(ttf.family, font_name, ttf.encoding_name);
        },
    }
}

fn renderPage(self: *Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, page: Page) !void {
    _ = c.HPDF_Page_SetWidth(hpage, page.frame.width);
    _ = c.HPDF_Page_SetHeight(hpage, page.frame.height);

    if (self.is_debug) {
        grid.printGrid(hpdf, hpage);
    }

    if (page.background_color) |background_color| {
        try self.drawBackground(hpage, background_color, page.frame);
    }

    if (page.border) |border| {
        try self.drawBorder(hpage, border, page.content_frame);
    }

    try self.renderContainer(hpdf, hpage, page.content_frame, page.alignment, page.container);
}

fn renderContainer(self: *Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, rect: Rect, alignment: ?Alignment, container: Container.Container) !void {
    switch (container) {
        .box => {
            const box = container.box;
            const content_frame = try self.renderBox(hpdf, hpage, rect, alignment, box);
            try self.content_frame_map.put(box.id, content_frame);

            if (self.is_debug) {
                try self.drawBorder(hpage, Border.init(Color.init("FF0000"), Border.Style.dash, 0.5, 0.5, 0.5, 0.5), content_frame);
                _ = c.HPDF_Page_BeginText(hpage);
                _ = c.HPDF_Page_SetRGBFill(hpage, 1.0, 0.0, 0.0);
                _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
                _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY, "Page container's drawable rect.");
                _ = c.HPDF_Page_EndText(hpage);
            }

            if (box.child) |child| {
                const child_container: *Container.Container = @ptrCast(*Container.Container, @alignCast(@alignOf(Container.Container), child));
                try self.renderContainer(hpdf, hpage, content_frame, box.alignment, child_container.*);
            }
        },
        .positioned_box => {
            const positioned_box = container.positioned_box;
            const content_frame = try self.renderPositionedBox(hpdf, hpage, rect, positioned_box);
            try self.content_frame_map.put(positioned_box.id, content_frame);

            if (self.is_debug) {
                try self.drawBorder(hpage, Border.init(Color.init("0000FF"), Border.Style.dot, 0.5, 0.5, 0.5, 0.5), content_frame);
                _ = c.HPDF_Page_BeginText(hpage);
                _ = c.HPDF_Page_SetRGBFill(hpage, 1.0, 0.0, 0.0);
                _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
                _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY, "Positioned box's drawable rect.");
                _ = c.HPDF_Page_EndText(hpage);
            }

            if (positioned_box.child) |child| {
                const child_container: *Container.Container = @ptrCast(*Container.Container, @alignCast(@alignOf(Container.Container), child));
                try self.renderContainer(hpdf, hpage, content_frame, null, child_container.*);
            }
        },
        .column => {
            const column = container.column;
            var content_frame = rect;

            if (self.is_debug) {
                try self.drawBorder(hpage, Border.init(Color.init("F00FFF"), Border.Style.dot, 0.5, 0.5, 0.5, 0.5), content_frame);
                _ = c.HPDF_Page_BeginText(hpage);
                _ = c.HPDF_Page_SetRGBFill(hpage, 1.0, 0.0, 0.0);
                _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
                _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY, "Columns's drawable rect.");
                _ = c.HPDF_Page_EndText(hpage);
            }

            var children_width: f32 = 0;
            var children_height: f32 = 0;

            for (column.children) |child| {
                const child_container_ptr: *Container.Container = @ptrCast(*Container.Container, @alignCast(@alignOf(Container.Container), child));
                const child_container = child_container_ptr.*;
                try self.renderContainer(hpdf, hpage, content_frame, null, child_container);
                if (self.content_frame_map.get(child_container.getId())) |child_content_frame| {
                    content_frame = content_frame.offsetLTWH(0, child_content_frame.height, content_frame.width, content_frame.height - child_content_frame.height);

                    children_width = if (children_width < child_content_frame.width) child_content_frame.width else children_width;
                    children_height += child_content_frame.height;
                }
            }

            var wrap_frame = Rect.fromPoints(rect.minX, rect.maxY, rect.minX + children_width, rect.maxY - children_height);
            try self.content_frame_map.put(column.id, wrap_frame);
        },
        .row => {
            const row = container.row;
            var content_frame = rect;

            if (self.is_debug) {
                try self.drawBorder(hpage, Border.init(Color.init("F00FFF"), Border.Style.dot, 0.5, 0.5, 0.5, 0.5), content_frame);
                _ = c.HPDF_Page_BeginText(hpage);
                _ = c.HPDF_Page_SetRGBFill(hpage, 1.0, 0.0, 0.0);
                _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
                _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY, "Rows's drawable rect.");
                _ = c.HPDF_Page_EndText(hpage);
            }

            var children_width: f32 = 0;
            var children_height: f32 = 0;

            for (row.children) |child| {
                const child_container_ptr: *Container.Container = @ptrCast(*Container.Container, @alignCast(@alignOf(Container.Container), child));
                const child_container = child_container_ptr.*;
                try self.renderContainer(hpdf, hpage, content_frame, null, child_container);
                if (self.content_frame_map.get(child_container.getId())) |child_content_frame| {
                    content_frame = content_frame.offsetLTWH(child_content_frame.width, 0, content_frame.width - child_content_frame.width, content_frame.height);

                    children_width += child_content_frame.width;
                    children_height = if (children_height < child_content_frame.height) child_content_frame.height else children_height;
                }
            }

            var wrap_frame = Rect.fromPoints(rect.minX, rect.maxY, rect.minX + children_width, rect.maxY - children_height);
            try self.content_frame_map.put(row.id, wrap_frame);
        },
        .image => {
            const image = container.image;
            const content_frame = try self.renderImage(hpdf, hpage, rect, alignment, image);
            try self.content_frame_map.put(image.id, content_frame);

            if (self.is_debug) {
                try self.drawBorder(hpage, Border.init(Color.init("00FFFF"), Border.Style.dot, 0.5, 0.5, 0.5, 0.5), content_frame);
                _ = c.HPDF_Page_BeginText(hpage);
                _ = c.HPDF_Page_SetRGBFill(hpage, 1.0, 0.0, 0.0);
                _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
                _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY, "Image's rect.");
                _ = c.HPDF_Page_EndText(hpage);
            }
        },
        .text => {
            const text = container.text;
            const content_frame = try self.renderText(hpdf, hpage, rect, alignment, text);
            try self.content_frame_map.put(text.id, content_frame);

            if (self.is_debug) {
                try self.drawBorder(hpage, Border.init(Color.init("FF00FF"), Border.Style.dot, 0.5, 0.5, 0.5, 0.5), content_frame);
            }
        },
    }
}

fn renderBox(self: Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, parent_rect: Rect, alignment: ?Alignment, box: Container.Box) !Rect {
    _ = hpdf;

    const size = box.size orelse parent_rect.size;
    const pad = box.padding orelse Padding.zeroPadding;
    const width = if (box.expanded) (parent_rect.size.width / size.width) * size.width else size.width;
    const height = if (box.expanded) (parent_rect.size.height / size.height) * size.height else size.height;

    var content_frame = parent_rect.offsetLTWH(0, 0, width, height);

    if (box.size != null and alignment != null) {
        const x = (alignment.?.x * (box.size.?.width / 2) + (box.size.?.width / 2)) - (alignment.?.x * parent_rect.width / 2);
        const y = (alignment.?.y * (box.size.?.height / 2) + (box.size.?.height / 2)) - (alignment.?.y * parent_rect.height / 2);
        content_frame = parent_rect.offsetCenterXYWH(x * -1, y * -1, box.size.?.width, box.size.?.height);
    }

    if (box.border) |border| {
        try self.drawBorder(hpage, border, content_frame);
    }

    if (box.background_color) |background_color| {
        try self.drawBackground(hpage, background_color, content_frame);
    }

    return content_frame.insets(pad.top, pad.right, pad.bottom, pad.left);
}

fn renderPositionedBox(self: Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, parent_rect: Rect, positioned_box: Container.PositionedBox) !Rect {
    _ = self;
    _ = hpdf;
    _ = hpage;

    if (positioned_box.size == null) {
        return parent_rect.insets(positioned_box.top orelse 0, positioned_box.right orelse 0, positioned_box.bottom orelse 0, positioned_box.left orelse 0);
    }

    const size = positioned_box.size.?;

    var x: f32 = 0;
    var y: f32 = 0;
    if (positioned_box.left) |left| {
        x = left;
    }
    if (positioned_box.right) |right| {
        x = parent_rect.width - size.width - right;
    }
    if (positioned_box.top) |top| {
        y = top;
    }
    if (positioned_box.bottom) |bottom| {
        y = parent_rect.height - size.height - bottom;
    }

    const content_frame = parent_rect.offsetLTWH(x, y, size.width, size.height);

    return content_frame;
}

fn renderImage(self: Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, parent_rect: Rect, alignment: ?Alignment, image: Container.Image) !Rect {
    _ = self;

    const extension = std.fs.path.extension(image.path);
    const himage = if (std.mem.eql(u8, extension, ".png")) c.HPDF_LoadPngImageFromFile(hpdf, image.path.ptr) else c.HPDF_LoadJpegImageFromFile(hpdf, image.path.ptr);
    const imageWidth: f32 = @intToFloat(f32, c.HPDF_Image_GetWidth(himage));
    const imageHeight: f32 = @intToFloat(f32, c.HPDF_Image_GetHeight(himage));

    const size = image.size orelse Size.init(imageWidth, imageHeight);

    var content_frame = parent_rect.offsetLTWH(0, 0, size.width, size.height);

    if (image.size != null and alignment != null) {
        const x = (alignment.?.x * (image.size.?.width / 2) + (image.size.?.width / 2)) - (alignment.?.x * parent_rect.width / 2);
        const y = (alignment.?.y * (image.size.?.height / 2) + (image.size.?.height / 2)) - (alignment.?.y * parent_rect.height / 2);
        content_frame = parent_rect.offsetCenterXYWH(x * -1, y * -1, image.size.?.width, image.size.?.height);
    }

    _ = c.HPDF_Page_DrawImage(hpage, himage, content_frame.minX, content_frame.minY, content_frame.width, content_frame.height);

    return content_frame;
}

fn renderText(self: Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, parent_rect: Rect, alignment: ?Alignment, text: Container.Text) !Rect {
    _ = c.HPDF_Page_BeginText(hpage);

    const font: Font.NamedFont = self.font_map.get(text.font_family) orelse @panic("undefined font.");
    const hfont: c.HPDF_Font = c.HPDF_GetFont(hpdf, font.name.ptr, if (font.encoding_name == null) null else font.encoding_name.?.ptr);

    const text_size = text.text_size;
    const word_space = text.word_space;
    const char_space = text.char_space;
    var soft_wrap = text.soft_wrap;

    _ = c.HPDF_Page_SetFontAndSize(hpage, hfont, text_size);
    _ = c.HPDF_Page_SetWordSpace(hpage, word_space);
    _ = c.HPDF_Page_SetCharSpace(hpage, char_space);

    const text_len = @intCast(c_uint, text.content.len);
    const text_width = c.HPDF_Font_TextWidth(hfont, text.content.ptr, text_len);
    const width = ((@intToFloat(f32, text_width.width) / 1000) * text_size) + (word_space * @intToFloat(f32, text_width.numwords - 1)) + (char_space * @intToFloat(f32, text_width.numchars - 1));
    // const ascent = ((@intToFloat(f32, c.HPDF_Font_GetAscent(hfont)) / 1000) * text_size);
    const descent = (@intToFloat(f32, c.HPDF_Font_GetDescent(hfont) * -1) / 1000) * text_size;
    // const font_height = ascent + descent;
    const b_box = c.HPDF_Font_GetBBox(hfont);
    const line_height = ((b_box.top + (b_box.bottom * -1)) / 1000) * text_size;
    var size = Size.init(width, line_height);

    _ = c.HPDF_Page_SetTextLeading(hpage, line_height);

    if (soft_wrap) {
        // ページ設定で指定した幅の中に配置できる文字の数を計算する - HPDF_Page_MeasureText
        // 指定した幅の中に配置できる文字の数を計算する - HPDF_Font_MeasureText
        var real_width: c.HPDF_REAL = 0;
        // _ = c.HPDF_Page_MeasureText(hpage, text.content.ptr, parent_rect.width, c.HPDF_FALSE, &real_width);
        _ = c.HPDF_Font_MeasureText(hfont, text.content.ptr, text_len, parent_rect.width, text_size, char_space, word_space, c.HPDF_FALSE, &real_width);
        if (size.width - real_width > 1.0) {
            const number_lines = @ceil(size.width / real_width);
            size = Size.init(real_width, line_height * number_lines);
        } else {
            soft_wrap = false;
        }
    }

    var content_frame = parent_rect.offsetLTWH(0, 0, size.width, size.height);

    if (alignment != null) {
        const x = (alignment.?.x * (size.width / 2) + (size.width / 2)) - (alignment.?.x * parent_rect.width / 2);
        const y = (alignment.?.y * (size.height / 2) + (size.height / 2)) - (alignment.?.y * parent_rect.height / 2);
        content_frame = parent_rect.offsetCenterXYWH(x * -1, y * -1, size.width, size.height);
    }

    _ = c.HPDF_Page_SetRGBFill(hpage, 0.0, 0.0, 0.0);
    if (text.color.value) |hex| {
        const rgb = try Rgb.hex(hex);
        const red = @intToFloat(f32, rgb.red) / 255;
        const green = @intToFloat(f32, rgb.green) / 255;
        const blue = @intToFloat(f32, rgb.blue) / 255;
        _ = c.HPDF_Page_SetRGBFill(hpage, red, green, blue);
    }

    _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);

    // 指定した領域内にテキストを表示する - HPDF_Page_TextRect
    // 指定した位置にテキストを表示する - HPDF_Page_TextOut
    // ページの現在位置にテキストを表示する - HPDF_Page_ShowText
    if (soft_wrap) {
        // "HPDF_Page_TextRect" は単語の途中で改行されない
        // _ = c.HPDF_Page_TextRect(hpage, content_frame.minX, content_frame.maxY, content_frame.maxX, content_frame.minY, text.content.ptr, c.HPDF_TALIGN_LEFT, null);

        var iter = (try std.unicode.Utf8View.init(text.content)).iterator();

        _ = c.HPDF_Page_MoveTextPos(hpage, content_frame.minX, content_frame.maxY - line_height + descent);
        var x: f32 = 0;
        var w: f32 = 0;
        var buf: [4]u8 = undefined;
        while (iter.nextCodepoint()) |cp| {
            var bytes = try std.unicode.utf8CodepointSequenceLength(cp);

            if (bytes > 1) {
                var utf8 = try self.allocator.alloc(u8, bytes);
                defer self.allocator.free(utf8);
                _ = try std.unicode.utf8Encode(cp, utf8);

                var sjis = try Encode.encodeSjis(self.allocator, utf8);
                defer self.allocator.free(sjis);

                x = c.HPDF_Page_GetCurrentTextPos(hpage).x;
                w = emToPoint(@intToFloat(f32, c.HPDF_Font_TextWidth(hfont, sjis.ptr, 1).width), text_size);
                if (x + w > content_frame.maxX) {
                    _ = c.HPDF_Page_MoveToNextLine(hpage);
                }
                _ = c.HPDF_Page_ShowText(hpage, sjis.ptr);

                continue;
            }

            var s = try std.fmt.bufPrintZ(&buf, "{u}", .{cp});
            x = c.HPDF_Page_GetCurrentTextPos(hpage).x;
            w = emToPoint(@intToFloat(f32, c.HPDF_Font_TextWidth(hfont, s.ptr, 1).width), text_size);
            if (x + w > content_frame.maxX) {
                _ = c.HPDF_Page_MoveToNextLine(hpage);
            }
            _ = c.HPDF_Page_ShowText(hpage, s.ptr);
        }
    } else {
        const sjis = try Encode.encodeSjis(self.allocator, text.content);
        defer self.allocator.free(sjis);

        _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY + descent, sjis.ptr);
    }

    _ = c.HPDF_Page_EndText(hpage);

    return content_frame;
}

fn drawBackground(self: Self, hpage: c.HPDF_Page, color: Color, rect: Rect) !void {
    _ = self;

    if (color.value) |hex| {
        const rgb = try Rgb.hex(hex);
        _ = c.HPDF_Page_SetRGBFill(hpage, @intToFloat(f32, rgb.red) / 255, @intToFloat(f32, rgb.green) / 255, @intToFloat(f32, rgb.blue) / 255);
        _ = c.HPDF_Page_MoveTo(hpage, rect.minX, rect.minY);
        _ = c.HPDF_Page_LineTo(hpage, rect.minX, rect.maxY);
        _ = c.HPDF_Page_LineTo(hpage, rect.maxX, rect.maxY);
        _ = c.HPDF_Page_LineTo(hpage, rect.maxX, rect.minY);
        _ = c.HPDF_Page_Fill(hpage);
    }
}

fn drawBorder(self: Self, hpage: c.HPDF_Page, border: Border, rect: Rect) !void {
    _ = self;

    const rgb = try Rgb.hex(border.color.value.?);
    const red = @intToFloat(f32, rgb.red) / 255;
    const green = @intToFloat(f32, rgb.green) / 255;
    const blue = @intToFloat(f32, rgb.blue) / 255;

    switch (border.style) {
        Border.Style.dash => {
            _ = c.HPDF_Page_SetDash(hpage, &[_]c.HPDF_REAL{3}, 1, 1);
        },
        Border.Style.dot => {
            // _ = c.HPDF_Page_SetLineCap (hpage, c.HPDF_ROUND_END);
            _ = c.HPDF_Page_SetDash(hpage, &[_]c.HPDF_REAL{0.5}, 1, 1);
        },
        else => {
            _ = c.HPDF_Page_SetDash(hpage, null, 0, 0);
        },
    }

    if (border.top != 0 and border.right != 0 and border.bottom != 0 and border.left != 0) {
        const width = (border.top + border.right + border.bottom + border.left) / 4;
        _ = c.HPDF_Page_SetLineWidth(hpage, width);
        _ = c.HPDF_Page_SetRGBStroke(hpage, red, green, blue);
        _ = c.HPDF_Page_Rectangle(hpage, rect.minX, rect.minY, rect.width, rect.height);
        _ = c.HPDF_Page_Stroke(hpage);
        return;
    }

    if (border.top != 0) {
        _ = c.HPDF_Page_SetLineWidth(hpage, border.top);
        _ = c.HPDF_Page_SetRGBStroke(hpage, red, green, blue);
        _ = c.HPDF_Page_MoveTo(hpage, rect.minX, rect.maxY);
        _ = c.HPDF_Page_LineTo(hpage, rect.maxX, rect.maxY);
        _ = c.HPDF_Page_Stroke(hpage);
    }

    if (border.right != 0) {
        _ = c.HPDF_Page_SetLineWidth(hpage, border.right);
        _ = c.HPDF_Page_SetRGBStroke(hpage, red, green, blue);
        _ = c.HPDF_Page_MoveTo(hpage, rect.maxX, rect.maxY);
        _ = c.HPDF_Page_LineTo(hpage, rect.maxX, rect.minY);
        _ = c.HPDF_Page_Stroke(hpage);
    }

    if (border.bottom != 0) {
        _ = c.HPDF_Page_SetLineWidth(hpage, border.bottom);
        _ = c.HPDF_Page_SetRGBStroke(hpage, red, green, blue);
        _ = c.HPDF_Page_MoveTo(hpage, rect.maxX, rect.minY);
        _ = c.HPDF_Page_LineTo(hpage, rect.minX, rect.minY);
        _ = c.HPDF_Page_Stroke(hpage);
    }

    if (border.left != 0) {
        _ = c.HPDF_Page_SetLineWidth(hpage, border.left);
        _ = c.HPDF_Page_SetRGBStroke(hpage, red, green, blue);
        _ = c.HPDF_Page_MoveTo(hpage, rect.minX, rect.minY);
        _ = c.HPDF_Page_LineTo(hpage, rect.minX, rect.maxY);
        _ = c.HPDF_Page_Stroke(hpage);
    }
}

fn emToPoint(em: f32, text_size: f32) f32 {
    return (em / 1000) * text_size;
}

fn errorEandler(error_no: c.HPDF_STATUS, detail_no: c.HPDF_STATUS, user_data: ?*anyopaque) callconv(.C) void {
    _ = user_data;
    std.log.err("ERROR: error_no={}, detail_no={}", .{ error_no, detail_no });
}

test "permission" {
    const permissions = [_]PermissionName{
        PermissionName.read,
    };

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Box.init(false, null, null, null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
    };

    var fonts = [_]Font.FontFace{
        Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null))
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "permission", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/permission.pdf");
}

test "page" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    const text_color = Color.init(Default.text_color);
    const char_space_0 = 0;
    const word_space_0 = 0;

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Text.init("Background color #EFEFEF", text_color, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 842)), Color.init("EFEFEF"), null, null, null),
        Page.init(Container.wrap(Container.Text.init("Padding color (10, 10, 10, 10)", text_color, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Text.init("Alignment top x left", text_color, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.topLeft, null),
        Page.init(Container.wrap(Container.Text.init("Alignment top x center", text_color, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.topCenter, null),
        Page.init(Container.wrap(Container.Text.init("Alignment top x right", text_color, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.topRight, null),
        Page.init(Container.wrap(Container.Text.init("Alignment center x left", text_color, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.centerLeft, null),
        Page.init(Container.wrap(Container.Text.init("Alignment center", text_color, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.center, null),
        Page.init(Container.wrap(Container.Text.init("Alignment center x right", text_color, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.centerRight, null),
        Page.init(Container.wrap(Container.Text.init("Alignment bottom x left", text_color, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.bottomLeft, null),
        Page.init(Container.wrap(Container.Text.init("Alignment bottom x center", text_color, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.bottomCenter, null),
        Page.init(Container.wrap(Container.Text.init("Alignment bottom x right", text_color, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 595)), null, null, Alignment.bottomRight, null),
        Page.init(Container.wrap(Container.Text.init("Border", text_color, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, Border.init(Color.init("0FF0FF"), Border.Style.dot, 5, 5, 5, 5)),
        Page.init(Container.wrap(Container.Text.init("All page properties", text_color, Default.text_size, "Default", true, char_space_0, word_space_0)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(50, 50, 50, 50), Alignment.topRight, Border.init(Color.init("FFF00F"), Border.Style.dot, 5, 5, 5, 5)),
    };

    var fonts = [_]Font.FontFace{
        Font.wrap(Font.NamedFont.init("Default", "MS-Gothic", "90ms-RKSJ-H")),
        Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null)),
        Font.wrap(Font.Ttf.init("MPLUS1p-Thin", "src/fonts/MPLUS1p-Thin.ttf", true, null)),
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "page", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/page.pdf");
}

test "box" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    const char_space_0 = 0;
    const word_space_0 = 0;
    const text_size_30 = 30;

    var child = Container.wrap(Container.Box.init(false, null, Color.init("DEDEDE"), null, null, null, Size.init(200, 200)));
    const opaque_child: *anyopaque = &child;

    var text = Container.wrap(Container.Text.init("Hello World :)", Color.init("000FFF"), text_size_30, "Default", false, char_space_0, word_space_0));
    const opaque_text: *anyopaque = &text;

    var text2 = Container.wrap(Container.Text.init("Hello World :)", Color.init("000FFF"), Default.text_size, "Default", false, char_space_0, word_space_0));
    const opaque_text2: *anyopaque = &text2;

    var child2 = Container.wrap(Container.Box.init(false, null, Color.init("DEDEDE"), null, opaque_text2, Padding.init(10, 10, 10, 10), Size.init(200, 200)));
    const opaque_child2: *anyopaque = &child2;

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Box.init(false, null, null, null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, Alignment.center, null, null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, null, Color.init("EFEFEF"), null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, null, null, Border.init(Color.init("0FF0FF"), Border.Style.dot, 1, 1, 1, 1), null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, null, null, null, null, Padding.init(10, 10, 10, 10), null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, null, null, null, null, null, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, Alignment.center, Color.init("EFEFEF"), Border.init(Color.init("0FF0FF"), Border.Style.dot, 1, 1, 1, 1), null, Padding.init(10, 10, 10, 10), Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), Alignment.center, null),
        Page.init(Container.wrap(Container.Box.init(false, null, null, null, null, null, Size.init(600, 900))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Box.init(true, null, null, null, null, null, Size.init(600, 900))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Box.init(false, Alignment.bottomRight, Color.init("EFEFEF"), null, opaque_child, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, Alignment.bottomLeft, Color.init("EFEFEF"), null, opaque_child2, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
        Page.init(Container.wrap(Container.Box.init(false, Alignment.center, null, null, opaque_text, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
    };

    var fonts = [_]Font.FontFace{
        Font.wrap(Font.NamedFont.init("Default", "MS-Gothic", "90ms-RKSJ-H")),
        Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null))
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "box", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/box.pdf");
}

test "positioned_box" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    var child = Container.wrap(Container.PositionedBox.init(null, null, null, 50, 50, Size.init(100, 100)));
    const opaque_child: *anyopaque = &child;

    var pages = [_]Page{
        Page.init(Container.wrap(Container.PositionedBox.init(null, 50, null, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, null, 50, null, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, null, null, 50, null, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, null, null, null, 50, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, null, null, null, null, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, 50, 50, 50, 50, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, 50, 50, null, null, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, null, null, 50, 50, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(null, null, 50, 50, null, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.PositionedBox.init(opaque_child, 50, 50, null, null, Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
    };

    var fonts = [_]Font.FontFace{
        Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null))
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "positioned_box", CompressionMode.text, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/positioned_box.pdf");
}

test "image" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    // const mesured_size1 = Measure.image("src/images/sample.jpg");
    // const mesured_size2 = Measure.image("src/images/sample.png");

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Image.init("src/images/sample.jpg", null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Image.init("src/images/sample.png", null)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Image.init("src/images/sample.png", Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(Container.Image.init("src/images/sample.png", Size.init(100, 100))), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.center, null),
    };

    var fonts = [_]Font.FontFace{
        Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null))
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "image", CompressionMode.image, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/image.pdf");
}

test "text" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    const text_color = Color.init(Default.text_color);
    const text_size_20 = 20;
    const text_size_30 = 30;
    const char_space_0 = 0;
    const char_space_2 = 2;
    const char_space_10 = 10;
    const word_space_0 = 0;
    const word_space_5 = 5;
    const word_space_10 = 10;

    // const text_metrics1 = Measure.text("Hello TypogrAphy. (default)", Default.text_size, default_font, char_space_0, word_space_0);
    const text1 = Container.Text.init("Hello TypogrAphy. (default)", text_color, Default.text_size, "Default", false, char_space_0, word_space_0);

    const text2 = Container.Text.init("Hello TypogrAphy. (change color)", Color.init("FF00FF"), Default.text_size, "Default", false, char_space_0, word_space_0);

    const text3 = Container.Text.init("Hello TypogrAphy. (change size)", text_color, text_size_20, "Default", false, char_space_0, word_space_0);

    const text4 = Container.Text.init("Hello TypogrAphy. (change font face to helvetica)", text_color, Default.text_size, "Helvetica", false, char_space_0, word_space_0);

    const text5 = Container.Text.init("Hello TypogrAphy. (change font face to mplus1p)", text_color, Default.text_size, "MPLUS1p-Thin", false, char_space_0, word_space_0);

    const text6 = Container.Text.init("Hello TypogrAphy1. Hello TypogrAphy2. Hello TypogrAphy3. Hello TypogrAphy4. Hello TypogrAphy5. Hello TypogrAphy6. Hello TypogrAphy7. Hello TypogrAphy8. Hello TypogrAphy9. Hello TypogrAphy10. Hello TypogrAphy11. Hello TypogrAphy12.", text_color, Default.text_size, "Default", true, char_space_0, word_space_0);

    const text7 = Container.Text.init("Hello TypogrAphy. (change character space)", text_color, Default.text_size, "Default", false, char_space_10, word_space_0);

    const text8 = Container.Text.init("Hello TypogrAphy. (change word space)", text_color, Default.text_size, "Default", false, char_space_0, word_space_10);

    const text9 = Container.Text.init("Hello TypogrAphy. (mix)", Color.init("FF00FF"), text_size_30, "Helvetica", false, char_space_2, word_space_5);

    const text10 = Container.Text.init("Hello TypogrAphy. (mix)", Color.init("FF00FF"), text_size_30, "Helvetica", true, char_space_2, word_space_5);

    const text11 = Container.Text.init("こんにちは　タイポグラフィ。(デフォルト)", text_color, text_size_30, "MPLUS1p-Thin", false, char_space_2, word_space_5);

    const text12 = Container.Text.init("こんにちは　タイポグラフィ。(デフォルト)", text_color, text_size_30, "MPLUS1p-Thin", true, char_space_2, word_space_5);

    var pages = [_]Page{
        Page.init(Container.wrap(text1), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text2), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text3), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text4), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text5), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text6), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text7), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text8), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text9), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.center, null),
        Page.init(Container.wrap(text10), Size.init(@as(f32, 200), @as(f32, 300)), null, null, Alignment.center, null),
        Page.init(Container.wrap(text11), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.wrap(text12), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
    };

    var fonts = [_]Font.FontFace{
        Font.wrap(Font.NamedFont.init("Default", "MS-Gothic", "90ms-RKSJ-H")),
        Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null)),
        Font.wrap(Font.Ttf.init("MPLUS1p-Thin", "src/fonts/MPLUS1p-Thin.ttf", true, "90msp-RKSJ-H")),
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "text", CompressionMode.image, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/text.pdf");
}

test "column" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    var box1 = Container.wrap(Container.Box.init(false, null, Color.init("00F0F0"), null, null, null, Size.init(100, 50)));
    const opaque_box1: *anyopaque = &box1;

    var box2 = Container.wrap(Container.Box.init(false, null, Color.init("F00FFF"), null, null, null, Size.init(100, 50)));
    const opaque_box2: *anyopaque = &box2;

    var children = [_]*anyopaque{
        opaque_box1,
        opaque_box2,
    };

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Column.init(&children, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
    };

    var fonts = [_]Font.FontFace{
        Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null))
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "column", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/column.pdf");
}

test "row" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    var box1 = Container.wrap(Container.Box.init(false, null, Color.init("00F0F0"), null, null, null, Size.init(100, 50)));
    const opaque_box1: *anyopaque = &box1;

    var box2 = Container.wrap(Container.Box.init(false, null, Color.init("F00FFF"), null, null, null, Size.init(100, 50)));
    const opaque_box2: *anyopaque = &box2;

    var children = [_]*anyopaque{
        opaque_box1,
        opaque_box2,
    };

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Row.init(&children, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
    };

    var fonts = [_]Font.FontFace{
        Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null))
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "column", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/row.pdf");
}

test "row_column" {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.edit_all,
    };

    const char_space_0 = 0;
    const word_space_0 = 0;

    var text1 = Container.wrap(Container.Text.init("Box1 Box1 Box1 Box1 Box1 Box1", Color.init("000FFF"), Default.text_size, "Default", true, char_space_0, word_space_0));
    const opaque_text1: *anyopaque = &text1;

    var box1 = Container.wrap(Container.Box.init(false, null, Color.init("00F0F0"), null, opaque_text1, null, Size.init(100, 50)));
    const opaque_box1: *anyopaque = &box1;

    var text2 = Container.wrap(Container.Text.init("Box2", Color.init("000FFF"), Default.text_size, "Default", false, char_space_0, word_space_0));
    const opaque_text2: *anyopaque = &text2;

    var box2 = Container.wrap(Container.Box.init(false, null, Color.init("F00FFF"), null, opaque_text2, null, Size.init(100, 50)));
    const opaque_box2: *anyopaque = &box2;

    var boxes1 = [_]*anyopaque{
        opaque_box1,
        opaque_box2,
    };

    var text3 = Container.wrap(Container.Text.init("Box3", Color.init("000FFF"), Default.text_size, "Default", false, char_space_0, word_space_0));
    const opaque_text3: *anyopaque = &text3;

    var box3 = Container.wrap(Container.Box.init(false, null, Color.init("F0F0FF"), null, opaque_text3, null, Size.init(100, 50)));
    const opaque_box3: *anyopaque = &box3;

    var text4 = Container.wrap(Container.Text.init("Box4", Color.init("000FFF"), Default.text_size, "Default", false, char_space_0, word_space_0));
    const opaque_text4: *anyopaque = &text4;

    var box4 = Container.wrap(Container.Box.init(false, null, Color.init("F0FFF0"), null, opaque_text4, null, Size.init(100, 50)));
    const opaque_box4: *anyopaque = &box4;

    var boxes2 = [_]*anyopaque{
        opaque_box3,
        opaque_box4,
    };

    var column1 = Container.wrap(Container.Column.init(&boxes1, null));
    const opaque_column1: *anyopaque = &column1;

    var column2 = Container.wrap(Container.Column.init(&boxes2, null));
    const opaque_column2: *anyopaque = &column2;

    var children = [_]*anyopaque{
        opaque_column1,
        opaque_column2,
    };

    var pages = [_]Page{
        Page.init(Container.wrap(Container.Row.init(&children, null)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(10, 10, 10, 10), null, null),
    };

    var fonts = [_]Font.FontFace{
        Font.wrap(Font.NamedFont.init("Default", "MS-Gothic", "90ms-RKSJ-H")),
        Font.wrap(Font.NamedFont.init("Helvetica", "Helvetica", null))
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "column", CompressionMode.none, "password", null, EncryptionMode.Revision2, null, &permissions, &fonts, &pages);
    var pdfWriter = init(std.testing.allocator, pdf, true);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/row_column.pdf");
}
