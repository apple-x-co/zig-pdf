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
const default_font_encode_name = "90ms-RKSJ-H";
const default_font_name = "MS-Gothic";
const default_text_size: f32 = 8;
const EncryptionMode = @import("Encryption.zig").EncryptionMode;
const Font = @import("Pdf/Font.zig");
const Padding = @import("Pdf/Padding.zig");
const Page = @import("Pdf/Page.zig");
const Pdf = @import("Pdf.zig");
const PermissionName = @import("Permission.zig").PermissionName;
const Rect = @import("Pdf/Rect.zig");
const Rgb = @import("Pdf/Rgb.zig");
const Size = @import("Pdf/Size.zig");

allocator: std.mem.Allocator,
content_frame_map: std.AutoHashMap(u32, Rect),
// font_map: std.StringHashMap(c.HPDF_Font),
pdf: Pdf,

pub fn init(allocator: std.mem.Allocator, pdf: Pdf) Self {
    return .{
        .allocator = allocator,
        .content_frame_map = std.AutoHashMap(u32, Rect).init(allocator),
        // .font_map = std.StringHashMap(c.HPDF_Font).init(allocator),
        .pdf = pdf,
    };
}

pub fn deinit(self: *Self) void {
    self.content_frame_map.deinit();
    // self.font_map.deinit();
}

pub fn save(self: *Self, file_name: []const u8) !void {
    const hpdf = c.HPDF_New(null, null); // FIXME: self.errorEandler を指定するとエラーになる
    defer c.HPDF_Free(hpdf);

    self.setPdfAttributes(hpdf);

    // const font: c.HPDF_Font = c.HPDF_GetFont(hpdf, "MS-Gothic", "90ms-RKSJ-H");
    // try self.font_map.put("default", font);
    // _ = try self.font_map.get("default"); // FIXME: error: expected error union type, found '?[*c].xxxxx.zig-cache.o.f626383f61633cb0db6ac93886e75491.cimport.struct__HPDF_Dict_Rec'

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

fn renderPage(self: *Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, page: Page) !void {
    _ = c.HPDF_Page_SetWidth(hpage, page.frame.width);
    _ = c.HPDF_Page_SetHeight(hpage, page.frame.height);

    grid.printGrid(hpdf, hpage); // for debug

    if (page.background_color) |background_color| {
        try self.drawBackground(hpage, background_color, page.frame);
    }

    if (page.border) |border| {
        try self.drawBorder(hpage, border, page.content_frame);
    }

    try self.renderContainer(hpdf, hpage, page.content_frame, page.alignment, Container.wrap(page.container));
}

fn renderContainer(self: *Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, rect: Rect, alignment: ?Alignment, container: Container.Container) !void {
    switch (container) {
        .box => {
            const box = container.box;
            const content_frame = try self.renderBox(hpdf, hpage, rect, alignment, box);
            try self.content_frame_map.put(box.id, content_frame);

            // debug
            try self.drawBorder(hpage, Border.init(Color.init("FF0000"), Border.Style.dash, 0.5, 0.5, 0.5, 0.5), content_frame);
            _ = c.HPDF_Page_BeginText(hpage);
            _ = c.HPDF_Page_SetRGBFill(hpage, 1.0, 0.0, 0.0);
            _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
            // _ = c.HPDF_Page_MoveTextPos(hpage, content_frame.minX, content_frame.minY);
            // _ = c.HPDF_Page_ShowText(hpage, "HELLO!!");
            _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY, "Page container's drawable rect.");
            _ = c.HPDF_Page_EndText(hpage);
            // debug

            // debug positioned_box
            try self.renderContainer(hpdf, hpage, content_frame, Alignment.center, Container.wrap(Container.PositionedBox.init(10, null, null, 10, Size.init(20, 20))));
            try self.renderContainer(hpdf, hpage, content_frame, Alignment.center, Container.wrap(Container.PositionedBox.init(10, 10, null, null, Size.init(20, 20))));
            try self.renderContainer(hpdf, hpage, content_frame, Alignment.center, Container.wrap(Container.PositionedBox.init(null, 10, 10, null, Size.init(20, 20))));
            try self.renderContainer(hpdf, hpage, content_frame, Alignment.center, Container.wrap(Container.PositionedBox.init(null, null, 10, 10, Size.init(20, 20))));
            // debug

            // debug image
            try self.renderContainer(hpdf, hpage, content_frame, Alignment.topRight, Container.wrap(Container.Image.init("src/images/sample.jpg", Size.init(20, 20))));
            try self.renderContainer(hpdf, hpage, content_frame, Alignment.center, Container.wrap(Container.Image.init("src/images/sample.png", Size.init(20, 20))));
            try self.renderContainer(hpdf, hpage, content_frame, Alignment.bottomLeft, Container.wrap(Container.Image.init("src/images/sample.jpg", Size.init(20, 20))));
            // debug

            // debug text
            try self.renderContainer(hpdf, hpage, content_frame, Alignment.topCenter, Container.wrap(Container.Text.init("HELLO TypogrAphy.", Color.init("FF00FF"), 16, Font.wrap(Font.NamedFont.init("Helvetica", null)), null)));
            try self.renderContainer(hpdf, hpage, content_frame, Alignment.centerRight, Container.wrap(Container.Text.init("ABCDEFGHIJKLMNOPQRSTUVWXYZ.", null, null, Font.wrap(Font.Ttf.init("src/fonts/MPLUS1p-Thin.ttf", true, null)), null)));
            try self.renderContainer(hpdf, hpage, content_frame, Alignment.centerLeft, Container.wrap(Container.Text.init("HELLO TypogrAphy.", null, null, null, null)));
            try self.renderContainer(hpdf, hpage, content_frame, Alignment.bottomCenter, Container.wrap(Container.Text.init("HELLO TypogrAphy.", null, null, null, null)));
            // debug
        },
        .positioned_box => {
            const positioned_box = container.positioned_box;
            const content_frame = try self.renderPositionedBox(hpdf, hpage, rect, positioned_box);
            try self.content_frame_map.put(positioned_box.id, content_frame);

            // debug
            try self.drawBorder(hpage, Border.init(Color.init("0000FF"), Border.Style.dot, 0.5, 0.5, 0.5, 0.5), content_frame);
            _ = c.HPDF_Page_BeginText(hpage);
            _ = c.HPDF_Page_SetRGBFill(hpage, 1.0, 0.0, 0.0);
            _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
            // _ = c.HPDF_Page_MoveTextPos(hpage, content_frame.minX, content_frame.minY);
            // _ = c.HPDF_Page_ShowText(hpage, "HELLO!!");
            _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY, "Positioned box's drawable rect.");
            _ = c.HPDF_Page_EndText(hpage);
            // debug

            // debug text
            try self.renderContainer(hpdf, hpage, content_frame, alignment, Container.wrap(Container.Text.init("Typo grAp", null, 6, null, true)));
            // debug
        },
        .col => {},
        .row => {},
        .image => {
            const image = container.image;
            const content_frame = try self.renderImage(hpdf, hpage, rect, alignment, image);
            try self.content_frame_map.put(image.id, content_frame);

            // debug
            try self.drawBorder(hpage, Border.init(Color.init("00FFFF"), Border.Style.dot, 0.5, 0.5, 0.5, 0.5), content_frame);
            _ = c.HPDF_Page_BeginText(hpage);
            _ = c.HPDF_Page_SetRGBFill(hpage, 1.0, 0.0, 0.0);
            _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
            // _ = c.HPDF_Page_MoveTextPos(hpage, content_frame.minX, content_frame.minY);
            // _ = c.HPDF_Page_ShowText(hpage, "HELLO!!");
            _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY, "Image's rect.");
            _ = c.HPDF_Page_EndText(hpage);
            // debug
        },
        .text => {
            const text = container.text;
            const content_frame = try self.renderText(hpdf, hpage, rect, alignment, text);
            try self.content_frame_map.put(text.id, content_frame);

            // debug
            try self.drawBorder(hpage, Border.init(Color.init("FF00FF"), Border.Style.dot, 0.5, 0.5, 0.5, 0.5), content_frame);
            // debug
        },
    }
}

fn renderBox(self: Self, hpdf: c.HPDF_Doc, hpage: c.HPDF_Page, parent_rect: Rect, alignment: ?Alignment, box: Container.Box) !Rect {
    _ = hpdf;

    const size = box.size orelse parent_rect.size;
    const pad = box.padding orelse Padding.zeroPadding;
    const width = if (box.expanded) (parent_rect.size.width / size.width) * size.width else size.width;
    const height = size.height;

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

    const size = positioned_box.size orelse parent_rect.size;

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
    _ = self;

    var hfont: c.HPDF_Font = null;
    if (text.font) |font| {
        switch (font) {
            .named_font => {
                const named_font = font.named_font;
                hfont = c.HPDF_GetFont(hpdf, named_font.name.ptr, if (named_font.encoding_name == null) null else named_font.encoding_name.?.ptr);
            },
            .ttc => {
                const ttc = font.ttc;
                const name = c.HPDF_LoadTTFontFromFile2(hpdf, ttc.file_path.ptr, ttc.index, if (ttc.embedding) c.HPDF_TRUE else c.HPDF_FALSE);
                hfont = c.HPDF_GetFont(hpdf, name, if (ttc.encoding_name == null) null else ttc.encoding_name.?.ptr);
            },
            .ttf => {
                const ttf = font.ttf;
                const name = c.HPDF_LoadTTFontFromFile(hpdf, ttf.file_path.ptr, if (ttf.embedding) c.HPDF_TRUE else c.HPDF_FALSE);
                hfont = c.HPDF_GetFont(hpdf, name, if (ttf.encoding_name == null) null else ttf.encoding_name.?.ptr);
            },
            .type1 => {
                const type1 = font.type1;
                const name = c.HPDF_LoadType1FontFromFile(hpdf, type1.arm_file_path.ptr, type1.data_file_path.ptr);
                hfont = c.HPDF_GetFont(hpdf, name, if (type1.encoding_name == null) null else type1.encoding_name.?.ptr);
            },
        }
    }
    if (hfont == null) {
        hfont = c.HPDF_GetFont(hpdf, default_font_name, default_font_encode_name);
    }

    const text_size = text.text_size orelse default_text_size;
    _ = c.HPDF_Page_SetFontAndSize(hpage, hfont, text_size);
    const text_len = @intCast(c_uint, text.content.len);
    const width = (@intToFloat(f32, c.HPDF_Font_TextWidth(hfont, text.content.ptr, text_len).width) / 1000) * text_size;
    const ascent = ((@intToFloat(f32, c.HPDF_Font_GetAscent(hfont)) / 1000) * text_size);
    const descent = (@intToFloat(f32, c.HPDF_Font_GetDescent(hfont) * -1) / 1000) * text_size;
    const font_height = ascent + descent;
    var size = Size.init(width, font_height);
    var soft_wrap = text.soft_wrap;

    _ = c.HPDF_Page_SetWordSpace(hpage, 0); // TODO: 単語間隔
    _ = c.HPDF_Page_SetCharSpace(hpage, 0); // TODO: 文字間隔
    _ = c.HPDF_Page_SetTextLeading(hpage, font_height); // TODO: 行間隔

    if (soft_wrap) {
        const word_space = c.HPDF_Page_GetWordSpace(hpage);
        const char_space = c.HPDF_Page_GetCharSpace(hpage);
        // const text_leading = c.HPDF_Page_GetTextLeading(hpage);

        // ページ設定で指定した幅の中に配置できる文字の数を計算する - HPDF_Page_MeasureText
        // 指定した幅の中に配置できる文字の数を計算する - HPDF_Font_MeasureText
        var real_width: c.HPDF_REAL = 0;
        // _ = c.HPDF_Page_MeasureText(hpage, text.content.ptr, parent_rect.width, c.HPDF_FALSE, &real_width);
        _ = c.HPDF_Font_MeasureText(hfont, text.content.ptr, text_len, parent_rect.width, text_size, char_space, word_space, c.HPDF_FALSE, &real_width);
        if (size.width > real_width) {
            const number_lines = @ceil(size.width / real_width);
            size = Size.init(real_width, (font_height * number_lines));
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

    _ = c.HPDF_Page_BeginText(hpage);
    _ = c.HPDF_Page_SetRGBFill(hpage, 0.0, 0.0, 0.0);
    if (text.color) |text_color| {
        if (text_color.value) |hex| {
            const rgb = try Rgb.hex(hex);
            const red = @intToFloat(f32, rgb.red) / 255;
            const green = @intToFloat(f32, rgb.green) / 255;
            const blue = @intToFloat(f32, rgb.blue) / 255;
            _ = c.HPDF_Page_SetRGBFill(hpage, red, green, blue);
        }
    }
    _ = c.HPDF_Page_SetTextRenderingMode(hpage, c.HPDF_FILL);
    if (soft_wrap) {
        _ = c.HPDF_Page_TextRect(hpage, content_frame.minX, content_frame.maxY + descent, content_frame.maxX, content_frame.minY + descent, text.content.ptr, c.HPDF_TALIGN_LEFT, null);
    } else {
        _ = c.HPDF_Page_TextOut(hpage, content_frame.minX, content_frame.minY + descent, text.content.ptr);
    }
    _ = c.HPDF_Page_EndText(hpage);

    // 指定した領域内にテキストを表示する - HPDF_Page_TextRect
    // 指定した位置にテキストを表示する - HPDF_Page_TextOut
    // ページの現在位置にテキストを表示する - HPDF_Page_ShowText

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

fn errorEandler(error_no: c.HPDF_STATUS, detail_no: c.HPDF_STATUS, user_data: ?*anyopaque) callconv(.C) void {
    _ = user_data;

    const stdErr = std.io.getStdErr();
    std.fmt.format(stdErr, "ERROR: error_no={}, detail_no={}\n", .{ error_no, detail_no }) catch unreachable;
}

test {
    const permissions = [_]PermissionName{
        PermissionName.read,
        PermissionName.copy,
        PermissionName.print,
    };

    var pages = [_]Page{
        Page.init(Container.Box.init(false, null, null, null, null, null, null), Size.init(@as(f32, 595), @as(f32, 842)), null, null, null, null),
        Page.init(Container.Box.init(false, null, null, null, null, null, null), Size.init(@as(f32, 595), @as(f32, 842)), Color.init("EEEEEE"), Padding.init(10, 10, 10, 10), null, Border.init(Color.init("000090"), Border.Style.solid, 1, 1, 1, 1)),
        Page.init(Container.Box.init(false, null, Color.init("fef1ec"), Border.init(Color.init("f9aa8f"), Border.Style.solid, 1, 1, 1, 1), null, Padding.init(25, 25, 25, 25), Size.init(550, 550)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(50, 50, 50, 50), null, Border.init(Color.init("009000"), Border.Style.solid, 1, 1, 1, 1)),
        Page.init(Container.Box.init(true, null, Color.init("fef1ec"), Border.init(Color.init("f9aa8f"), Border.Style.solid, 1, 1, 1, 1), null, Padding.init(25, 25, 25, 25), Size.init(550, 550)), Size.init(@as(f32, 595), @as(f32, 842)), null, Padding.init(50, 50, 50, 50), null, Border.init(Color.init("009000"), Border.Style.solid, 1, 1, 1, 1)),
        Page.init(Container.Box.init(false, null, Color.init("fef1ec"), null, null, null, Size.init(100, 100)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.topLeft, null),
        Page.init(Container.Box.init(false, null, Color.init("fef1ec"), null, null, null, Size.init(100, 100)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.topCenter, null),
        Page.init(Container.Box.init(false, null, Color.init("fef1ec"), null, null, null, Size.init(100, 100)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.topRight, null),
        Page.init(Container.Box.init(false, null, Color.init("fef1ec"), null, null, null, Size.init(100, 100)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.centerLeft, null),
        Page.init(Container.Box.init(false, null, Color.init("fef1ec"), null, null, null, Size.init(100, 100)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.center, null),
        Page.init(Container.Box.init(false, null, Color.init("fef1ec"), null, null, null, Size.init(100, 100)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.centerRight, null),
        Page.init(Container.Box.init(false, null, Color.init("fef1ec"), null, null, null, Size.init(100, 100)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.bottomLeft, null),
        Page.init(Container.Box.init(false, null, Color.init("fef1ec"), null, null, null, Size.init(100, 100)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.bottomCenter, null),
        Page.init(Container.Box.init(false, null, Color.init("fef1ec"), null, null, null, Size.init(100, 100)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.bottomRight, null),
        Page.init(Container.Box.init(false, null, Color.init("fef1ec"), null, null, null, Size.init(300, 100)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.center, null),
        Page.init(Container.Box.init(false, null, Color.init("fef1ec"), null, null, null, Size.init(500, 100)), Size.init(@as(f32, 595), @as(f32, 842)), null, null, Alignment.center, null),
    };

    const pdf = Pdf.init("apple-x-co", "zig-pdf", "demo", "demo1", CompressionMode.image, "password", null, EncryptionMode.Revision2, null, &permissions, &pages);
    var pdfWriter = init(std.testing.allocator, pdf);
    defer pdfWriter.deinit();
    try pdfWriter.save("demo/demo.pdf");

    // TODO: Cleanup file
    // TODO: 一時ディレクトリw std.testing.tmpDir から取得できないか!?
}
