const std = @import("std");
const clap = @import("clap");
const print = std.debug.print;
const util = @import("util.zig");
const io = std.io;
const stdout_writer = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();
const ini = @import("ini.zig");
//gpa just to practice and catch leaks
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const Params = struct { is_special: bool, is_nummeric: bool, is_uppercase: bool, password_length: u32 };
var p = Params{ .is_special = true, .is_nummeric = true, .is_uppercase = true, .password_length = 15 };

pub fn main() !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-l, --length <INT>     Sets password length, default is 15
        \\-u, --uppercase        Excludes uppercase letters in password generation
        \\-s, --symbols          Excludes special symbols for password generation
        \\-n, --nummeric         Excludes numbers for password generation
        \\-w, --write  <STR>     Saves password to a file (maybe defined in .config or passed as arg <STR>)
        \\-f, --find  <STR>      Finds and prints out password if it exists
    );

    const parsers = comptime .{
        .STR = clap.parsers.string,
        .INT = clap.parsers.int(usize, 10),
    };

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(stderr, err) catch {};
        try stderr.print("You passed invalid character.Use --help to see more info.\n", .{});
        return;
    };
    var key_name: []const u8 = "";
    //matching possible parameters
    if (res.args.help != 0)
        return clap.help(stderr, clap.Help, &params, .{});
    if (res.args.symbols != 0)
        p.is_special = false;
    if (res.args.find) |key| {
        try util.printKey(key);
        return;
    }
    if (res.args.length) |l|
        p.password_length = @as(u32, @intCast(l));
    if (res.args.nummeric != 0)
        p.is_nummeric = false;
    if (res.args.uppercase != 0)
        p.is_uppercase = false;
    const final_char_pool_list = try util.passwordCharPool(p.is_uppercase, p.is_special, p.is_nummeric);
    const password = try util.generatePass(p.password_length, final_char_pool_list);

    if (res.args.write) |name| {
        var config_file = try util.openFile();
        var file_content = try util.returnFile(config_file);
        var pr = try ini.Parser.parse(file_content, allocator);
        defer pr.deinit();
        if (pr.keyExists(name)) {
            print("Key with that name already exists!\n", .{});
            return;
        } else {
            key_name = name;
            try util.saveValueUnderKey(key_name, password, config_file);
            defer config_file.close();
        }
    }
    try stdout_writer.print("{s}\n", .{password});

    //freeing memory
    defer {
        res.deinit();
        _ = gpa.deinit();
    }
}
