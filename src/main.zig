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

//gpa perhaps another allocater makes more sense ?
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const ArrayList = std.ArrayList;

var list = ArrayList(u8).init(allocator);
var pass_list = ArrayList(u8).init(allocator);

pub fn main() !void {
    //possible toggles and parameters with their default values, user can ofcourse override this
    var is_special: bool = true;
    var is_nummeric: bool = true;
    var is_uppercase: bool = true;
    var password_length: u32 = 15;
    //adding lowercase letter right away since they are not optionals
    try list.appendSlice(letters_lowercase);
    //freeing memory of the password list, this should be freed either way at the program exit (at least what i think atm)
    defer pass_list.deinit();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-l, --length <INT>     Sets password length, default is 15
        \\-u, --uppercase        Excludes uppercase letters in password generation
        \\-s, --symbols          Excludes special symbols for password generation
        \\-n, --nummeric         Excludes numbers for password generation
        \\-w, --write            Saves password to a file (maybe defined in .config or passed as arg <STR>)
    );

    const parsers = comptime .{
        .STR = clap.parsers.string,
        .INT = clap.parsers.int(usize, 10),
    };
    //diagnostic provided by zig-clap, need to improve error handling
    //(when i get wrong parameter should result in one error, but getting wrong parameter value)
    //should result in another error (ie, when i get float instead of int for length)
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(stderr, err) catch {};
        // print("{}", .{@TypeOf(err)});
        try stderr.print("You passed invalid character.Use --help to see more info.\n", .{});
        return;
    };
    //freeing memory
    defer res.deinit();
    defer _ = gpa.deinit();
    //matching possible parameters
    if (res.args.help != 0)
        return clap.help(stderr, clap.Help, &params, .{});
    if (res.args.symbols != 0)
        is_special = false;
    if (res.args.length) |l|
        password_length = @as(u32, @intCast(l));
    if (res.args.nummeric != 0)
        is_nummeric = false;
    if (res.args.uppercase != 0)
        is_uppercase = false;
    if (res.args.write != 0)
        print("I will save to file in future with custom name for the password field", .{});

    const final_char_list = try passwordCharPool(is_uppercase, is_special, is_nummeric);
    //i would like generate pass to return the u8 instead of void, but i get volatile asm error when attempting that
    try generatePass(password_length, final_char_list);
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

    try stdout_writer.print("{!s}\n", .{final_pass});
    defer allocator.free(char_list);
    defer allocator.free(final_pass);
}

// adds characters to the password based on user toggle
fn passwordCharPool(uppercase: bool, special: bool, numeric: bool) ![]u8 {
    defer list.deinit();
    if (special) {
        try list.appendSlice(special_chars);
        const new_pass = try pass_list.toOwnedSlice();

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

fn saveToFile() void {
    // to be implemented, this function should save password under key value file,
    // perhaps file could be encrypted somehow in the future, (to simulate somewhat of vault behaviour)
}
