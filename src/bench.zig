const std = @import("std");
const zbench = @import("zbench");
const coslcs = @import("coslcs");
const ClosestOffsetSumLCS = coslcs.ClosestOffsetSumLCS;

fn randomArray(random: std.Random, comptime length: comptime_int, comptime alphabet_size: comptime_int) [length]u8 {
    var array: [length]u8 = undefined;
    for (&array) |*element| {
        element.* = random.int(u8) % alphabet_size;
    }
    return array;
}

fn IterationBenchmark(comptime length: comptime_int, comptime alphabet_size: comptime_int) type {
    return struct {
        source: [length]u8,
        target: [length]u8,

        fn init(random: std.Random) @This() {
            return .{
                .source = randomArray(random, length, alphabet_size),
                .target = randomArray(random, length, alphabet_size),
            };
        }

        pub fn run(self: *@This(), _: std.mem.Allocator) void {
            var iterator = ClosestOffsetSumLCS(usize).init(&self.source, &self.target);
            while (iterator.next()) |value| {
                std.mem.doNotOptimizeAway(value);
            }
        }
    };
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    var seed: [8]u8 = undefined;
    try std.Io.randomSecure(init.io, &seed);

    var prng = std.Random.DefaultPrng.init(0xbe2c5561);

    var bench = zbench.Benchmark.init(allocator, .{});
    defer bench.deinit();

    const lengths = [_]comptime_int{ 10, 100, 250, 500 };
    const alphabet_sizes = [_]comptime_int{ 1, 2, 4, 16, 32, 64, 128, 255 };

    inline for (lengths) |length| {
        inline for (alphabet_sizes) |alphabet_size| {
            const name = std.fmt.comptimePrint(
                "ClosestOffsetSumLCS_L{d}_A{d}",
                .{ length, alphabet_size },
            );
            const benchmark = IterationBenchmark(length, alphabet_size).init(prng.random());
            try bench.addParam(name, &benchmark, .{});
        }
    }

    var stdout_writer = std.Io.File.stdout().writer(init.io, &.{});
    try stdout_writer.interface.writeAll("\n");
    try bench.run(init.io, std.Io.File.stdout());
}
