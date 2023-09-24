const std = @import("std");
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
const Padding = @import("Pdf/Padding.zig");
const Page = @import("Pdf/Page.zig");
const Pdf = @import("Pdf.zig");
const PermissionName = @import("Permission.zig").PermissionName;
const Rect = @import("Pdf/Rect.zig");
const Rgb = @import("Pdf/Rgb.zig");
const Size = @import("Pdf/Size.zig");
const Writer = @import("Writer.zig");

pub fn main() !void {
    // // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // // stdout is for the actual output of your application, for example if you
    // // are implementing gzip, then only the compressed bytes should be sent to
    // // stdout, not any debugging messages.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    // try stdout.print("Run `zig build test` to run the tests.\n", .{});

    // try bw.flush(); // don't forget to flush!

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var args = try std.process.ArgIterator.initWithAllocator(allocator);
    defer args.deinit();
    _ = args.next().?; // skip program name

    const stdout = std.io.getStdOut();
    const stderr = std.io.getStdErr();

    var arg = args.next();
    if (arg == null) {
        const stdin = std.io.getStdIn();
        generatePdf(stdin, stdout, stderr, allocator) catch |err| {
            std.log.warn("error reading from stdin : {}", .{err});
        };

        return;
    }

    while (true) : (arg = args.next()) {
        if (arg == null) {
            break;
        }

        const file = try std.fs.cwd().openFile(arg.?, .{ .mode = .read_only });
        defer file.close();
        generatePdf(file, stdout, stderr, allocator) catch |err| {
            std.log.warn("error reading from file '{s}': {}", .{ arg.?, err });
        };
    }
}

fn generatePdf(in: std.fs.File, out: std.fs.File, errOut: std.fs.File, allocator: std.mem.Allocator) anyerror!void {
    var parser = std.json.Parser.init(allocator, false);
    defer parser.deinit();

    const reader = in.reader();
    var payload = try reader.readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(payload);

    const err_writer = errOut.writer();
    var err_writer_buffer = std.io.bufferedWriter(err_writer);
    var parsed = parser.parse(payload) catch |err| {
        try err_writer.print("error: {s}\n", .{@errorName(err)});

        return;
    };
    defer parsed.deinit();

    const writer = out.writer();
    var write_buffer = std.io.bufferedWriter(writer);

    // // Output json string
    // try parsed.root.jsonStringify(std.json.StringifyOptions{
    //     .whitespace = std.json.StringifyOptions.Whitespace{}
    // }, writer);
    // try writer.print("\n", .{}); // debug code

    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    var arena_allocator = arena.allocator();

    var author: []const u8 = undefined;
    var creator: ?[]const u8 = null;
    var title: ?[]const u8 = null;
    var subject: ?[]const u8 = null;
    var compression = CompressionMode.none;
    var owner_password: ?[]const u8 = null;
    var user_password: ?[]const u8 = null;
    var encryption_mode: ?EncryptionMode = null;
    var encryption_length: ?u32 = null;

    if (parsed.root.Object.get("author")) |jv| {
        author = try arena_allocator.dupe(u8, jv.String);
    }

    if (parsed.root.Object.get("creator")) |jv| {
        creator = switch (jv) {
            .String => try arena_allocator.dupe(u8, jv.String),
            else => null,
        };
    }

    if (parsed.root.Object.get("title")) |jv| {
        title = try arena_allocator.dupe(u8, jv.String);
    }

    if (parsed.root.Object.get("subject")) |jv| {
        subject = switch (jv) {
            .String => try arena_allocator.dupe(u8, jv.String),
            else => null,
        };
    }

    if (parsed.root.Object.get("compression")) |jv| {
        var s = switch (jv) {
            .String => jv.String,
            else => "none",
        };
        if (std.mem.eql(u8, s, "none")) {
            compression = CompressionMode.none;
        }
        if (std.mem.eql(u8, s, "text")) {
            compression = CompressionMode.text;
        }
        if (std.mem.eql(u8, s, "image")) {
            compression = CompressionMode.image;
        }
        if (std.mem.eql(u8, s, "metadata")) {
            compression = CompressionMode.metadata;
        }
        if (std.mem.eql(u8, s, "all")) {
            compression = CompressionMode.all;
        }
    }

    if (parsed.root.Object.get("password")) |jv| {
        if (jv.Object.get("owner")) |v| {
            owner_password = switch (v) {
                .String => try arena_allocator.dupe(u8, v.String),
                else => null,
            };
        }
        if (jv.Object.get("user")) |v| {
            user_password = switch (v) {
                .String => try arena_allocator.dupe(u8, v.String),
                else => null,
            };
        }
    }

    if (parsed.root.Object.get("encryption")) |jv| {
        if (jv.Object.get("mode")) |v| {
            var s = switch (v) {
                .String => v.String,
                else => "",
            };
            if (std.mem.eql(u8, s, "Revision2")) {
                encryption_mode = EncryptionMode.Revision2;
            }
            if (std.mem.eql(u8, s, "Revision3")) {
                encryption_mode = EncryptionMode.Revision3;
            }
        }
        if (jv.Object.get("length")) |v| {
            var i = switch (v) {
                .Integer => v.Integer,
                else => 0,
            };
            if (i > 0) {
                encryption_length = @as(u32, @intCast(i));
            }
        }
    }

    var permission_names: []PermissionName = undefined;
    if (parsed.root.Object.get("permission")) |arr| {
        permission_names = try allocator.alloc(PermissionName, arr.Array.items.len);
        for (arr.Array.items, 0..) |jv, i| {
            var s = switch (jv) {
                .String => jv.String,
                else => "",
            };
            if (std.mem.eql(u8, s, "print")) {
                permission_names[i] = PermissionName.print;
                continue;
            }
            if (std.mem.eql(u8, s, "edit_all")) {
                permission_names[i] = PermissionName.edit_all;
                continue;
            }
            if (std.mem.eql(u8, s, "copy")) {
                permission_names[i] = PermissionName.copy;
                continue;
            }
            if (std.mem.eql(u8, s, "edit")) {
                permission_names[i] = PermissionName.edit;
                continue;
            }
            permission_names[i] = PermissionName.read;
        }
        permission_names = try allocator.realloc(permission_names, permission_names.len);
    }
    defer allocator.free(permission_names);

    var fonts: []Font.FontFace = undefined;
    if (parsed.root.Object.get("fonts")) |arr| {
        fonts = try allocator.alloc(Font.FontFace, arr.Array.items.len);
        for (arr.Array.items, 0..) |jv, i| {
            var fontType = jv.Object.get("type").?.String;

            if (std.mem.eql(u8, fontType, "default")) {
                var font_family = try arena_allocator.dupe(u8, jv.Object.get("family").?.String);
                var font_name = try arena_allocator.dupe(u8, jv.Object.get("name").?.String);
                var encoding_name = switch (jv.Object.get("encodingName").?) {
                    .String => try arena_allocator.dupe(u8, jv.Object.get("encodingName").?.String),
                    else => null,
                };
                fonts[i] = Font.wrap(Font.NamedFont.init(font_family, font_name, encoding_name));

                continue;
            }

            if (std.mem.eql(u8, fontType, "ttc")) {
                var font_family = try arena_allocator.dupe(u8, jv.Object.get("family").?.String);
                var font_file_path = try arena_allocator.dupe(u8, jv.Object.get("file_path").?.String);
                var font_index = @as(u32, @intCast(jv.Object.get("index").?.Integer));
                var font_embedding = jv.Object.get("embedding").?.Bool;
                var font_encoding_name = try arena_allocator.dupe(u8, jv.Object.get("encoding_name").?.String);
                fonts[i] = Font.wrap(Font.Ttc.init(font_family, font_file_path, font_index, font_embedding, font_encoding_name));

                continue;
            }

            if (std.mem.eql(u8, fontType, "ttc")) {
                var font_family = try arena_allocator.dupe(u8, jv.Object.get("family").?.String);
                var font_file_path = try arena_allocator.dupe(u8, jv.Object.get("file_path").?.String);
                var font_embedding = jv.Object.get("embedding").?.Bool;
                var font_encoding_name = try arena_allocator.dupe(u8, jv.Object.get("encoding_name").?.String);
                fonts[i] = Font.wrap(Font.Ttf.init(font_family, font_file_path, font_embedding, font_encoding_name));

                continue;
            }
        }
        fonts = try allocator.realloc(fonts, fonts.len);
    }
    defer allocator.free(fonts);

    var pages: []Page = undefined;
    if (parsed.root.Object.get("pages")) |arr| {
        pages = try allocator.alloc(Page, arr.Array.items.len);
        for (arr.Array.items, 0..) |jv, i| {
            var page_size = Size.init(
                @as(f32, @floatFromInt(jv.Object.get("pageSize").?.Object.get("width").?.Integer)),
                @as(f32, @floatFromInt(jv.Object.get("pageSize").?.Object.get("height").?.Integer)),
            );

            var page_background_color = Color.init("ffffff");
            var page_border: ?Border = null;
            var page_padding: ?Padding = null;

            if (jv.Object.get("backgroundColor")) |v| {
                page_background_color = Color.init(v.String);
            }

            if (jv.Object.get("border")) |v| {
                var page_border_top: ?f32 = null;
                var page_border_right: ?f32 = null;
                var page_border_bottom: ?f32 = null;
                var page_border_left: ?f32 = null;
                if (v.Object.get("top")) |vv| {
                    page_border_top = @as(f32, @floatFromInt(vv.Integer));
                }
                if (v.Object.get("right")) |vv| {
                    page_border_right = @as(f32, @floatFromInt(vv.Integer));
                }
                if (v.Object.get("bottom")) |vv| {
                    page_border_bottom = @as(f32, @floatFromInt(vv.Integer));
                }
                if (v.Object.get("left")) |vv| {
                    page_border_left = @as(f32, @floatFromInt(vv.Integer));
                }

                page_border = Border.init(
                    Color.init(v.Object.get("color").?.String),
                    Border.Style.solid,
                    page_border_top orelse 0,
                    page_border_right orelse 0,
                    page_border_bottom orelse 0,
                    page_border_left orelse 0,
                );
            }

            if (jv.Object.get("padding")) |v| {
                var page_padding_top: f32 = 0;
                var page_padding_right: f32 = 0;
                var page_padding_bottom: f32 = 0;
                var page_padding_left: f32 = 0;
                if (v.Object.get("top")) |vv| {
                    page_padding_top = @as(f32, @floatFromInt(vv.Integer));
                }
                if (v.Object.get("right")) |vv| {
                    page_padding_right = @as(f32, @floatFromInt(vv.Integer));
                }
                if (v.Object.get("bottom")) |vv| {
                    page_padding_bottom = @as(f32, @floatFromInt(vv.Integer));
                }
                if (v.Object.get("left")) |vv| {
                    page_padding_left = @as(f32, @floatFromInt(vv.Integer));
                }

                page_padding = Padding.init(page_padding_top, page_padding_right, page_padding_bottom, page_padding_left);
            }

            var container: Container.Container = try makeContainer(arena_allocator, jv.Object.get("container").?);

            const page = try arena_allocator.create(Page);
            page.* = Page.init(container, page_size, page_background_color, page_padding, null, page_border);
            pages[i] = page.*;
        }
    }
    defer allocator.free(pages);

    const pdf = Pdf.init(author, creator, title, subject, compression, owner_password, user_password, encryption_mode, encryption_length, permission_names, fonts, pages);
    var pdfWriter = Writer.init(allocator, pdf, false);
    defer pdfWriter.deinit();
    try pdfWriter.save("/tmp/zig-pdf-sample.pdf");

    try write_buffer.flush();
    try err_writer_buffer.flush();
}

fn makeContainer(allocator: std.mem.Allocator, jv: std.json.Value) !Container.Container {
    var container_type = jv.Object.get("type").?.String;

    if (std.mem.eql(u8, container_type, "box")) {
        var box_alignment: ?Alignment = null;
        var box_background_color: ?Color = null;
        var box_border: ?Border = null;
        var box_padding: ?Padding = null;
        var box_size: ?Size = null;

        if (jv.Object.get("alignment")) |v| {
            if (std.mem.eql(u8, v.String, "bottom_center")) {
                box_alignment = Alignment.bottomCenter;
            }
            if (std.mem.eql(u8, v.String, "bottom_left")) {
                box_alignment = Alignment.bottomLeft;
            }
            if (std.mem.eql(u8, v.String, "bottom_right")) {
                box_alignment = Alignment.bottomRight;
            }
            if (std.mem.eql(u8, v.String, "center")) {
                box_alignment = Alignment.center;
            }
            if (std.mem.eql(u8, v.String, "center_left")) {
                box_alignment = Alignment.centerLeft;
            }
            if (std.mem.eql(u8, v.String, "center_right")) {
                box_alignment = Alignment.centerRight;
            }
            if (std.mem.eql(u8, v.String, "top_center")) {
                box_alignment = Alignment.topCenter;
            }
            if (std.mem.eql(u8, v.String, "top_left")) {
                box_alignment = Alignment.topLeft;
            }
            if (std.mem.eql(u8, v.String, "top_right")) {
                box_alignment = Alignment.topRight;
            }
        }

        if (jv.Object.get("backgroundColor")) |v| {
            box_background_color = Color.init(v.String);
        }

        if (jv.Object.get("border")) |v| {
            var border_top: ?f32 = null;
            var border_right: ?f32 = null;
            var border_bottom: ?f32 = null;
            var border_left: ?f32 = null;
            if (v.Object.get("top")) |vv| {
                border_top = @as(f32, @floatFromInt(vv.Integer));
            }
            if (v.Object.get("right")) |vv| {
                border_right = @as(f32, @floatFromInt(vv.Integer));
            }
            if (v.Object.get("bottom")) |vv| {
                border_bottom = @as(f32, @floatFromInt(vv.Integer));
            }
            if (v.Object.get("left")) |vv| {
                border_left = @as(f32, @floatFromInt(vv.Integer));
            }

            box_border = Border.init(
                Color.init(v.Object.get("color").?.String),
                Border.Style.solid,
                border_top orelse 0,
                border_right orelse 0,
                border_bottom orelse 0,
                border_left orelse 0,
            );
        }

        if (jv.Object.get("padding")) |v| {
            var padding_top: f32 = 0;
            var padding_right: f32 = 0;
            var padding_bottom: f32 = 0;
            var padding_left: f32 = 0;
            if (v.Object.get("top")) |vv| {
                padding_top = @as(f32, @floatFromInt(vv.Integer));
            }
            if (v.Object.get("right")) |vv| {
                padding_right = @as(f32, @floatFromInt(vv.Integer));
            }
            if (v.Object.get("bottom")) |vv| {
                padding_bottom = @as(f32, @floatFromInt(vv.Integer));
            }
            if (v.Object.get("left")) |vv| {
                padding_left = @as(f32, @floatFromInt(vv.Integer));
            }

            box_padding = Padding.init(padding_top, padding_right, padding_bottom, padding_left);
        }

        if (jv.Object.get("size")) |v| {
            var width: f32 = 0;
            var height: f32 = 0;
            if (v.Object.get("width")) |vv| {
                width = @as(f32, @floatFromInt(vv.Integer));
            }
            if (v.Object.get("height")) |vv| {
                height = @as(f32, @floatFromInt(vv.Integer));
            }
            box_size = Size.init(width, height);
        }

        if (jv.Object.get("child")) |v| {
            // zig build run -- schema/demo/pdf.json

            // TODO: fix below error
            // thread 3819843 panic: access of inactive union field
            // /Users/sanokouhei/Documents/Repository/GitHub/apple-x-co/zig-pdf/src/Writer.zig:429:34: 0x10ef292fd in renderContainer (zig-pdf)
            //             const box = container.box;
            //                                  ^
            // /Users/sanokouhei/Documents/Repository/GitHub/apple-x-co/zig-pdf/src/Writer.zig:445:73: 0x10ef29601 in renderContainer (zig-pdf)
            //                 try self.renderContainer(hpdf, hpage, content_frame, box.alignment, child_container);
            //                                                                         ^
            // /Users/sanokouhei/Documents/Repository/GitHub/apple-x-co/zig-pdf/src/Writer.zig:86:87: 0x10ef2bda3 in save (zig-pdf)
            //         try self.renderContainer(hpdf, hpage, page.content_frame, page.alignment, page.container);
            //                                                                                       ^
            // /Users/sanokouhei/Documents/Repository/GitHub/apple-x-co/zig-pdf/src/main.zig:344:23: 0x10ef0c626 in generatePdf (zig-pdf)
            //     try pdfWriter.save("/tmp/zig-pdf-sample.pdf");
            //                       ^
            // /Users/sanokouhei/Documents/Repository/GitHub/apple-x-co/zig-pdf/src/main.zig:64:20: 0x10ef06e12 in main (zig-pdf)
            //         generatePdf(file, stdout, stderr, allocator) catch |err| {
            //                    ^
            // /Users/sanokouhei/.local/zig-macos-x86_64-0.10.1/lib/std/start.zig:614:37: 0x10ef0d258 in main (zig-pdf)
            //             const result = root.main() catch |err| {
            //                                     ^
            // ?

            var box_child = try makeContainer(allocator, v);
            const opaque_box_child_ptr: *anyopaque = &box_child;

            const box_ptr = try allocator.create(Container.Box);
            box_ptr.* = Container.Box.init(false, box_alignment, box_background_color, box_border, opaque_box_child_ptr, box_padding, box_size);

            const box_container_ptr = try allocator.create(Container.Container);
            box_container_ptr.* = Container.wrap(box_ptr.*);

            return box_container_ptr.*;

            // TODO: fix below error
            // thread 3035144 panic: access of inactive union field
            // /path-to/zig-pdf/src/Writer.zig:429:34: 0x108b1843d in renderContainer (zig-pdf)

            // var box_child = try makeContainer(allocator, v);
            // // const opaque_box_child_ptr: *anyopaque = &box_child;
            // const opaque_box_child: *anyopaque = try allocator.create(anyopaque);
            // _ = opaque_box_child;
            // opaque_box_child.* = &box_child;

            // const box_ptr = try allocator.create(Container.Box);
            // box_ptr.* = Container.Box.init(false, box_alignment, box_background_color, box_border, opaque_box_child, box_padding, box_size);

            // const box_container_ptr = try allocator.create(Container.Container);
            // box_container_ptr.* = Container.wrap(box_ptr.*);

            // std.log.warn("box_container_ptr:{any}", .{box_container_ptr});

            // return box_container_ptr.*;
        }

        const box_ptr = try allocator.create(Container.Box);
        box_ptr.* = Container.Box.init(false, box_alignment, box_background_color, box_border, null, box_padding, box_size);

        const box_container_ptr = try allocator.create(Container.Container);
        box_container_ptr.* = Container.wrap(box_ptr.*);

        return box_container_ptr.*;
    }

    // if (std.mem.eql(u8, container_type, "col")) {
    //     var column_alignment: ?Alignment = null;

    //     if (jv.Object.get("alignment")) |v| {
    //         if (std.mem.eql(u8, v.String, "bottom_center")) {
    //             column_alignment = Alignment.bottomCenter;
    //         }
    //         if (std.mem.eql(u8, v.String, "bottom_left")) {
    //             column_alignment = Alignment.bottomLeft;
    //         }
    //         if (std.mem.eql(u8, v.String, "bottom_right")) {
    //             column_alignment = Alignment.bottomRight;
    //         }
    //         if (std.mem.eql(u8, v.String, "center")) {
    //             column_alignment = Alignment.center;
    //         }
    //         if (std.mem.eql(u8, v.String, "center_left")) {
    //             column_alignment = Alignment.centerLeft;
    //         }
    //         if (std.mem.eql(u8, v.String, "center_right")) {
    //             column_alignment = Alignment.centerRight;
    //         }
    //         if (std.mem.eql(u8, v.String, "top_center")) {
    //             column_alignment = Alignment.topCenter;
    //         }
    //         if (std.mem.eql(u8, v.String, "top_left")) {
    //             column_alignment = Alignment.topLeft;
    //         }
    //         if (std.mem.eql(u8, v.String, "top_right")) {
    //             column_alignment = Alignment.topRight;
    //         }
    //     }

    //     // TODO: column.children
    //     var column_children: []*anyopaque = undefined;

    //     return Container.wrap(Container.Column.init(column_children, column_alignment));
    // }

    // if (std.mem.eql(u8, container_type, "image")) {
    //     var image_path = jv.Object.get("path").?.String;
    //     var image_size: ?Size = null;

    //     if (jv.Object.get("size")) |v| {
    //         var width: f32 = 0;
    //         var height: f32 = 0;

    //         if (v.Object.get("width")) |vv| {
    //             width = @intToFloat(f32, vv.Integer);
    //         }
    //         if (v.Object.get("height")) |vv| {
    //             height = @intToFloat(f32, vv.Integer);
    //         }

    //         image_size = Size.init(width, height);
    //     }

    //     return Container.wrap(Container.Image.init(image_path, image_size));
    // }

    // if (std.mem.eql(u8, container_type, "positioned_box")) {
    //     var pbox_alignment: ?Alignment = null;
    //     var pbox_top: ?f32 = null;
    //     var pbox_right: ?f32 = null;
    //     var pbox_bottom: ?f32 = null;
    //     var pbox_left: ?f32 = null;
    //     var pbox_size: ?Size = null;

    //     // alignment
    //     if (jv.Object.get("alignment")) |v| {
    //         if (std.mem.eql(u8, v.String, "bottom_center")) {
    //             pbox_alignment = Alignment.bottomCenter;
    //         }
    //         if (std.mem.eql(u8, v.String, "bottom_left")) {
    //             pbox_alignment = Alignment.bottomLeft;
    //         }
    //         if (std.mem.eql(u8, v.String, "bottom_right")) {
    //             pbox_alignment = Alignment.bottomRight;
    //         }
    //         if (std.mem.eql(u8, v.String, "center")) {
    //             pbox_alignment = Alignment.center;
    //         }
    //         if (std.mem.eql(u8, v.String, "center_left")) {
    //             pbox_alignment = Alignment.centerLeft;
    //         }
    //         if (std.mem.eql(u8, v.String, "center_right")) {
    //             pbox_alignment = Alignment.centerRight;
    //         }
    //         if (std.mem.eql(u8, v.String, "top_center")) {
    //             pbox_alignment = Alignment.topCenter;
    //         }
    //         if (std.mem.eql(u8, v.String, "top_left")) {
    //             pbox_alignment = Alignment.topLeft;
    //         }
    //         if (std.mem.eql(u8, v.String, "top_right")) {
    //             pbox_alignment = Alignment.topRight;
    //         }
    //     }

    //     if (jv.Object.get("top")) |v| {
    //         pbox_top = @intToFloat(f32, v.Integer);
    //     }

    //     if (jv.Object.get("right")) |v| {
    //         pbox_right = @intToFloat(f32, v.Integer);
    //     }

    //     if (jv.Object.get("bottom")) |v| {
    //         pbox_bottom = @intToFloat(f32, v.Integer);
    //     }

    //     if (jv.Object.get("left")) |v| {
    //         pbox_left = @intToFloat(f32, v.Integer);
    //     }

    //     if (jv.Object.get("size")) |v| {
    //         var width: f32 = 0;
    //         var height: f32 = 0;

    //         if (v.Object.get("width")) |vv| {
    //             width = @intToFloat(f32, vv.Integer);
    //         }
    //         if (v.Object.get("height")) |vv| {
    //             height = @intToFloat(f32, vv.Integer);
    //         }

    //         pbox_size = Size.init(width, height);
    //     }

    //     // TODO: positioned_box.child

    //     return Container.wrap(Container.PositionedBox.init(null, pbox_top, pbox_right, pbox_bottom, pbox_left, pbox_size));
    // }

    // if (std.mem.eql(u8, container_type, "row")) {
    //     var row_alignment: ?Alignment = null;

    //     if (jv.Object.get("alignment")) |v| {
    //         if (std.mem.eql(u8, v.String, "bottom_center")) {
    //             row_alignment = Alignment.bottomCenter;
    //         }
    //         if (std.mem.eql(u8, v.String, "bottom_left")) {
    //             row_alignment = Alignment.bottomLeft;
    //         }
    //         if (std.mem.eql(u8, v.String, "bottom_right")) {
    //             row_alignment = Alignment.bottomRight;
    //         }
    //         if (std.mem.eql(u8, v.String, "center")) {
    //             row_alignment = Alignment.center;
    //         }
    //         if (std.mem.eql(u8, v.String, "center_left")) {
    //             row_alignment = Alignment.centerLeft;
    //         }
    //         if (std.mem.eql(u8, v.String, "center_right")) {
    //             row_alignment = Alignment.centerRight;
    //         }
    //         if (std.mem.eql(u8, v.String, "top_center")) {
    //             row_alignment = Alignment.topCenter;
    //         }
    //         if (std.mem.eql(u8, v.String, "top_left")) {
    //             row_alignment = Alignment.topLeft;
    //         }
    //         if (std.mem.eql(u8, v.String, "top_right")) {
    //             row_alignment = Alignment.topRight;
    //         }
    //     }

    //     // TODO: row.children
    //     var row_children: []*anyopaque = undefined;

    //     return Container.wrap(Container.Row.init(row_children, row_alignment));
    // }

    if (std.mem.eql(u8, container_type, "text")) {
        var text_char_space: f32 = 0;
        var text_content = jv.Object.get("content").?.String;
        var text_fill_color = Color.init("000000");
        var text_size: f32 = 10;
        var text_stroke_color: ?Color = null;
        var text_style = Container.Text.Style.fill;
        var text_font_family: []const u8 = undefined;
        var text_white_space: f32 = 0;
        var text_soft_wrap: bool = false;

        if (jv.Object.get("char_space")) |v| {
            text_char_space = @as(f32, @floatFromInt(v.Integer));
        }

        if (jv.Object.get("fill_color")) |v| {
            text_fill_color = Color.init(v.String);
        }

        if (jv.Object.get("stroke_color")) |v| {
            text_stroke_color = Color.init(v.String);
        }

        if (jv.Object.get("font_family")) |v| {
            text_font_family = v.String;
        }

        if (jv.Object.get("text_size")) |v| {
            text_size = @as(f32, @floatFromInt(v.Integer));
        }

        if (jv.Object.get("text_style")) |v| {
            if (std.mem.eql(u8, v.String, "fill")) {
                text_style = Container.Text.Style.fill;
            }
            if (std.mem.eql(u8, v.String, "stroke")) {
                text_style = Container.Text.Style.stroke;
            }
            if (std.mem.eql(u8, v.String, "fill_and_stroke")) {
                text_style = Container.Text.Style.fill_and_stroke;
            }
        }

        if (jv.Object.get("hite_space")) |v| {
            text_white_space = @as(f32, @floatFromInt(v.Integer));
        }

        if (jv.Object.get("soft_wrap")) |v| {
            text_soft_wrap = v.Bool;
        }

        const text_ptr = try allocator.create(Container.Text);
        text_ptr.* = Container.Text.init(text_content, text_fill_color, text_stroke_color, text_style, text_size, text_font_family, text_soft_wrap, text_char_space, text_white_space);

        const text_container_ptr = try allocator.create(Container.Container);
        text_container_ptr.* = Container.wrap(text_ptr.*);

        return text_container_ptr.*;
    }

    const empty_box_ptr = try allocator.create(Container.Box);
    empty_box_ptr.* = Container.Box.init(false, null, null, null, null, null, null);

    const empty_box_container_ptr = try allocator.create(Container.Container);
    empty_box_container_ptr.* = Container.wrap(empty_box_ptr.*);

    return empty_box_container_ptr.*;
}

test {
    // FIXME
}
