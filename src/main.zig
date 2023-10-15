const std = @import("std");
const clap = @import("clap");

const print = std.debug.print;
const io = std.io;
const stdout_writer = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

//constant values to create random strings, divided by categories
const numbers = "0123456789";
const special_chars = "!@#$%^&*()_+?></.,\\][";
const letters_lowercase = "aqwertyuiopsdfghjklzxcvbnm";
const letters_uppercase = "AQWERTYUIOPSDFGHJKLZXCVBNM";
const help_text =
    \\Display this help and exit.                       
    \\Sets password length, default is 15              
    \\Excludes uppercase letters in password generation
    \\Excludes special symbols for password generation 
    \\Excludes numbers for password generation
;

//gpa perhaps another allocater makes more sense ?
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const ArrayList = std.ArrayList;

var list = ArrayList(u8).init(allocator);
var pass_list = ArrayList(u8).init(allocator);

pub fn main() !u8 {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.                                   
        \\-l, --length <INT>     Sets password length, default is 15              
        \\-u, --uppercase        Excludes uppercase letters in password generation
        \\-s, --symbols          Excludes special symbols for password generation 
        \\-n, --nummeric         Excludes numbers for password generation
        \\-g, --generate         Generates a password with default parameters              
    );

    //possible toggles and parameters
    var is_special: bool = true;
    var is_nummeric: bool = true;
    var is_uppercase: bool = true;
    var password_length: u32 = 15;
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
        return 1;
    };
    defer res.deinit();
    defer _ = gpa.deinit();

    if (res.args.help != 0)
        try stdout_writer.print("{s}\n", .{help_text});
    if (res.args.symbols != 0)
        is_special = false;
    if (res.args.length) |l|
        password_length = @as(u32, @intCast(l));
    if (res.args.nummeric != 0)
        is_nummeric = false;
    if (res.args.uppercase != 0)
        is_uppercase = false;
    if (res.args.generate != 0) {
        const final_char_list = try passwordCharPool(is_uppercase, is_special, is_nummeric);
        try generatePass(password_length, final_char_list);
    } else {
        try stdout_writer.print("You need to pass -g flag to generate a password", .{});
    }

    return 0;
}

// randomizes password character
fn generatePass(length: u32, char_list: []u8) !void {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    var i: usize = 0;
    while (i < length) {
        var num = rand.intRangeAtMost(u8, 0, @as(u8, @intCast(char_list.len)) - 1);
        try pass_list.append(char_list[num]);
        i += 1;
    }
    const final_pass = try pass_list.toOwnedSlice();

    print("{!s}\n", .{final_pass});
    defer allocator.free(char_list);
    defer allocator.free(final_pass);
}

// parameters have to be determened by the user, using zig clap probably
fn passwordCharPool(uppercase: bool, special: bool, numeric: bool) ![]u8 {
    defer list.deinit();
    defer pass_list.deinit();
    try list.appendSlice(letters_lowercase);
    if (special) {
        try list.appendSlice(special_chars);
        const new_pass = try pass_list.toOwnedSlice();

        print("{!s}\n", .{new_pass});
        defer allocator.free(new_pass);
    }
    if (numeric) {
        try list.appendSlice(numbers);
    }
    if (uppercase) {
        try list.appendSlice(letters_uppercase);
    }
    return try list.toOwnedSlice();
}
