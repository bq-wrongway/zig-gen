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

var character_pool_list = ArrayList(u8).init(allocator);
var password = ArrayList(u8).init(allocator);

const Params = struct {
    is_special: bool,
    is_nummeric: bool,
    is_uppercase: bool,
    password_length: u32,
};
//possible toggles and parameters with their default values, user can ofcourse override this
var p = Params{
    .is_special = true,
    .is_nummeric = true,
    .is_uppercase = true,
    .password_length = 15,
};

pub fn main() !void {
    //adding lowercase letter right away since they are not optionals
    try character_pool_list.appendSlice(letters_lowercase);
    //freeing memory of the password list, this should be freed either way at the program exit (at least what i think atm)

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
        try stderr.print("You passed invalid character.Use --help to see more info.\n", .{});
        return;
    };

    //matching possible parameters
    if (res.args.help != 0)
        return clap.help(stderr, clap.Help, &params, .{});
    if (res.args.symbols != 0)
        p.is_special = false;
    if (res.args.length) |l|
        p.password_length = @as(u32, @intCast(l));
    if (res.args.nummeric != 0)
        p.is_nummeric = false;
    if (res.args.uppercase != 0)
        p.is_uppercase = false;
    if (res.args.write != 0)
        print("I will save to file in future with custom name for the password field", .{});

    const final_char_list = try passwordCharPool(p.is_uppercase, p.is_special, p.is_nummeric);
    const mypas = try generatePass(p.password_length, final_char_list);

    //freeing memory
    defer {
        password.deinit();
        allocator.free(mypas);
        allocator.free(final_char_list);
        res.deinit();
        _ = gpa.deinit();
    }

    try stdout_writer.print("{s}\n", .{mypas});
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
        try password.append(char_list[num]);
        i += 1;
    }

    return password.toOwnedSlice();
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

fn saveToFile() void {
    // to be implemented, this function should save password under key value file,
    // perhaps file could be encrypted somehow in the future, (to simulate somewhat of vault behaviour)
}
