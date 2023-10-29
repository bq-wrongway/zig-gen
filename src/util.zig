const ini = @import("ini.zig");
const std = @import("std");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const numbers = "0123456789";
const special_chars = "!@#$%^&*()_+?></.,\\][";
const letters_lowercase = "aqwertyuiopsdfghjklzxcvbnm";
const letters_uppercase = "AQWERTYUIOPSDFGHJKLZXCVBNM";

const allocator = gpa.allocator();
var character_pool_list = std.ArrayList(u8).init(allocator);
var password_list = std.ArrayList(u8).init(allocator);

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

pub fn saveValueUnderKey(name: []const u8, pass: []const u8, file: std.fs.File) !void {
    var stat = try file.stat();
    try file.seekTo(stat.size);
    // just for testing at the moment
    try file.writer().writeAll(name);
    try file.writer().writeAll(" = ");
    try file.writer().writeAll(pass);
    try file.writer().writeAll("\n");
}

pub fn createFile() !std.fs.File {
    const home = std.os.getenv("HOME").?;
    var home_dir = try std.fs.cwd().openDir(home, .{});
    var config_dir = try home_dir.makeOpenPath(".config/zig-gen", .{});
    var config_file = config_dir.openFile("conf.ini", .{ .mode = .read_write }) catch |err| {
        std.debug.print("could not open file {any}", .{err});
        return err;
    };
    return config_file;
}
pub fn openFile() !std.fs.File {
    const home = std.os.getenv("HOME").?;
    var home_dir = try std.fs.cwd().openDir(home, .{});
    var config_dir = try home_dir.makeOpenPath(".config/zig-gen", .{});
    var config_file = config_dir.openFile("conf.ini", .{ .mode = .read_write }) catch |err| {
        std.debug.print("could not open file {any}", .{err});
        return err;
    };

    return config_file;
}

pub fn returnFile(config_file: std.fs.File) ![]u8 {
    return try config_file.readToEndAlloc(allocator, std.math.maxInt(u32));
}

pub fn printKey(key: []const u8) !void {
    var file = try std.fs.cwd().openFile("file.ini", .{});
    defer file.close();
    const file_content = try file.readToEndAlloc(allocator, std.math.maxInt(u32));
    defer allocator.free(file_content);
    var pr = try ini.Parser.parse(file_content, allocator);
    defer pr.deinit();
    var key_val = pr.get(key).?;
    std.debug.print("key iz: {s}\n", .{key_val});
}

const FileOpenError = error{
    AccessDenied,
    FileNotFount,
};

// adds characters to the password based on user toggle
pub fn passwordCharPool(uppercase: bool, special: bool, numeric: bool) ![]u8 {
    //adding lowercase letter right away since they are not optionals
    character_pool_list.appendSlice(letters_lowercase) catch |err| {
        std.debug.print("Could not add to the slice {?} ", .{err});
        return err;
    };

    if (special) {
        try character_pool_list.appendSlice(special_chars);
    }
    if (numeric) {
        try character_pool_list.appendSlice(numbers);
    }
    if (uppercase) {
        try character_pool_list.appendSlice(letters_uppercase);
    }
    return try character_pool_list.toOwnedSlice();
}

// randomizes password character
pub fn generatePass(length: u32, char_list: []u8) ![]u8 {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    var i: usize = 0;
    while (i < length) {
        var num = rand.intRangeAtMost(u8, 0, @as(u8, @intCast(char_list.len)) - 1);
        try password_list.append(char_list[num]);
        i += 1;
    }
    return try password_list.toOwnedSlice();
}
