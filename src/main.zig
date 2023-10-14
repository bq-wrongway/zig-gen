const std = @import("std");
const print = std.debug.print;

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
    defer _ = gpa.deinit();
    const final_char_list = try passwordCharPool(true, true, true);
    try generatePass(15, final_char_list);
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
