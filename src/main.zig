const std = @import("std");

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
        pdf(stdin, stdout, stderr, allocator) catch |err| {
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
        pdf(file, stdout, stderr, allocator) catch |err| {
            std.log.warn("error reading from file '{s}': {}", .{ arg.?, err });
        };
    }
}

fn pdf(in: std.fs.File, out: std.fs.File, errOut: std.fs.File, allocator: std.mem.Allocator) anyerror!void {
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
    try parsed.root.jsonStringify(std.json.StringifyOptions{
        .whitespace = std.json.StringifyOptions.Whitespace{}
    }, writer);
    try writer.print("\n", .{}); // debug code
    
    try write_buffer.flush(); 
    try err_writer_buffer.flush();
}

test {
    // FIXME
}