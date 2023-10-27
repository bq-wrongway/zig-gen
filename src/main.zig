const std = @import("std");
const clap = @import("clap");
const print = std.debug.print;
const fs = @import("fs.zig");
const io = std.io;
const stdout_writer = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();
//constant values to create random strings, divided by categories
const numbers = "0123456789";
const special_chars = "!@#$%^&*()_+?></.,\\][";
const letters_lowercase = "aqwertyuiopsdfghjklzxcvbnm";
const letters_uppercase = "AQWERTYUIOPSDFGHJKLZXCVBNM";

//gpa perhaps another allocater makes more sense ?
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
const ArrayList = std.ArrayList;

var character_pool_list = ArrayList(u8).init(allocator);
var password_list = ArrayList(u8).init(allocator);

const Params = struct { is_special: bool, is_nummeric: bool, is_uppercase: bool, password_length: u32 };

var p = Params{ .is_special = true, .is_nummeric = true, .is_uppercase = true, .password_length = 15 };

pub fn main() !void {
    //adding lowercase letter right away since they are not optionals
    character_pool_list.appendSlice(letters_lowercase) catch |err| {
        try stderr.print("Could not add to the slice {?} ", .{err});
        return;
    };
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
        try fs.printKey(key);
        return;
    }
    if (res.args.length) |l|
        p.password_length = @as(u32, @intCast(l));
    if (res.args.nummeric != 0)
        p.is_nummeric = false;
    if (res.args.uppercase != 0)
        p.is_uppercase = false;
    const final_char_pool_list = try passwordCharPool(p.is_uppercase, p.is_special, p.is_nummeric);
    const password = try generatePass(p.password_length, final_char_pool_list);
    if (res.args.write) |name| {
        var booer = fs.keyExists(name) catch |err| {
            print("There was an error opening file! {?}", .{err});
            return;
        };
        if (booer) {
            print("Key with that name already exists!\n", .{});
            return;
        } else {
            key_name = name;
            try fs.saveValueUnderKey(key_name, password);
        }
    }

    //freeing memory
    defer {
        password_list.deinit();
        allocator.free(password);
        allocator.free(final_char_pool_list);
        res.deinit();
        _ = gpa.deinit();
        defer fs.deinit();
    }

    try stdout_writer.print("{s}\n", .{password});
    // var mt = fs.parseFileForKey() catch "could not open file";
    // print("{s}", .{mt});

}

// randomizes password character
fn generatePass(length: u32, char_list: []u8) ![]u8 {
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

    return password_list.toOwnedSlice();
}

// adds characters to the password based on user toggle
fn passwordCharPool(uppercase: bool, special: bool, numeric: bool) ![]u8 {
    defer character_pool_list.deinit();
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
