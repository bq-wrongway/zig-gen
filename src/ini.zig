const std = @import("std");

const string = []const u8;
const Allocator = std.mem.Allocator;

pub const Parser = struct {
    data: std.StringArrayHashMap(string),
    arena: std.heap.ArenaAllocator,

    pub fn parse(input: string, ally: Allocator) !Parser {
        var p = Parser{
            .data = undefined,
            .arena = std.heap.ArenaAllocator.init(ally),
        };
        p.data = std.StringArrayHashMap(string).init(p.arena.allocator());
        try p.data.ensureTotalCapacity(32);
        errdefer p.deinit();

        var stream = std.io.fixedBufferStream(input);
        const r = stream.reader();
        while (try r.readUntilDelimiterOrEofAlloc(p.arena.allocator(), '\n', std.math.maxInt(u32))) |line| {
            const trimmed_line = std.mem.trim(u8, line, "\r\n\t");
            if (trimmed_line.len == 0) continue;
            if (trimmed_line[0] == '#') continue;

            if (std.mem.indexOfScalar(u8, trimmed_line, '=')) |i| {
                const key = std.mem.trim(u8, trimmed_line[0 .. i - 1], "\r\t ");
                const value = std.mem.trim(u8, trimmed_line[i + 1 ..], "\r\t ");
                try p.data.put(key, value);
            }
        }

        return p;
    }

    pub fn deinit(p: *Parser) void {
        p.arena.deinit();
        p.* = undefined;
    }

    pub fn get(p: *Parser, key: string) ?string {
        return p.data.get(key);
    }

    pub fn getOrDefault(p: *Parser, key: string, default: string) !string {
        const e = try p.data.getOrPutValue(key, default);
        if (e.found_existing) return e.value_ptr.*;
        return default;
    }
    pub fn keyExists(p: *Parser, key: string) bool {
        return if (p.data.get(key) != null) true else false;
    }
};
