const ini = @import("ini.zig");
const std = @import("std");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
const result = std.os.getenv("HOME").?;

pub fn parseFileForKey() ![]const u8 {
    var file = try std.fs.cwd().openFile("file.ini", .{});
    defer file.close();
    const file_content = try file.readToEndAlloc(allocator, std.math.maxInt(u32));
    defer allocator.free(file_content);
    var pr = try ini.Parser.parse(file_content, allocator);
    defer pr.deinit();

    var key_value = pr.get("hello") orelse "No way ";
    std.debug.print("Result :{s}\n", .{key_value});
    return key_value;
}

pub fn deinit() void {
    _ = gpa.deinit();
}

pub fn saveValueUnderKey(name: []const u8, pass: []const u8) !void {
    var file = try std.fs.cwd().openFile("file.ini", .{ .mode = .read_write });
    var stat = try file.stat();
    try file.seekTo(stat.size);
    // just for testing at the moment
    try file.writer().writeAll(name);
    try file.writer().writeAll(" = ");
    try file.writer().writeAll(pass);
    try file.writer().writeAll("\n");
}

// pub fn checkIfDirExists() !void {
//     // var full_path = result ++ "/home/melnibone/.config/foot/foot.ini";
//     var file = try std.fs.openFileAbsolute("/home/melnibone/.config/foot/foot.ini", .{ .mode = .read_write });
//     var stat = try file.stat();
//     try file.seekTo(stat.size);

//     try file.writer().writeAll("test");
// }

pub fn keyExists(key: []const u8) !bool {
    var file = try std.fs.cwd().openFile("file.ini", .{});
    defer file.close();
    const file_content = try file.readToEndAlloc(allocator, std.math.maxInt(u32));
    defer allocator.free(file_content);
    var pr = try ini.Parser.parse(file_content, allocator);
    defer pr.deinit();
    return pr.keyExists(key);
}

const FileOpenError = error{
    AccessDenied,
    FileNotFount,
};
