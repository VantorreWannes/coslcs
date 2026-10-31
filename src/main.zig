const std = @import("std");
const coslcs = @import("coslcs");

const usage =
    \\usage: coslcs <source> <target>
    \\
;

fn readFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) ![]u8 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var reader = file.reader(io, &.{});
    return reader.interface.allocRemaining(allocator, .unlimited);
}

fn percent(part: usize, whole: usize) f64 {
    if (whole == 0) return 0;
    return 100.0 * @as(f64, @floatFromInt(part)) / @as(f64, @floatFromInt(whole));
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var stdout_writer = std.Io.File.stdout().writer(io, &.{});
    const out = &stdout_writer.interface;

    const arguments = try init.minimal.args.toSlice(allocator);
    defer allocator.free(arguments);

    const positional = if (arguments.len > 0) arguments[1..] else arguments;
    if (positional.len != 2) {
        try out.writeAll(usage);
        return;
    }

    const source = try readFile(allocator, io, positional[0]);
    defer allocator.free(source);
    const target = try readFile(allocator, io, positional[1]);
    defer allocator.free(target);

    var matched: std.ArrayList(u8) = .empty;
    defer matched.deinit(allocator);

    var iterator = coslcs.ClosestOffsetSumLCS(usize).init(source, target);
    while (iterator.next()) |value| try matched.append(allocator, value);

    const count = matched.items.len;
    try out.print("matched {d} pair(s)\n", .{count});
    try out.print("source  {d}/{d} ({d:.1}%)\n", .{ count, source.len, percent(count, source.len) });
    try out.print("target  {d}/{d} ({d:.1}%)\n", .{ count, target.len, percent(count, target.len) });
    try out.print("text    {s}\n", .{matched.items});
}
