const std = @import("std");

pub fn ClosestOffsetSumLCS(comptime Index: type) type {
    const index_info = @typeInfo(Index);
    if (index_info != .int or index_info.int.signedness != .unsigned) {
        @compileError("ClosestOffsetSumLCS requires an unsigned integer index type");
    }

    const NO_INDEX = std.math.maxInt(Index);

    return struct {
        const Self = @This();

        pub const Pair = struct {
            value: u8,
            source_index: Index,
            target_index: Index,
        };

        source: []const u8,
        target: []const u8,
        source_index: usize,
        target_index: usize,

        pub fn init(source: []const u8, target: []const u8) Self {
            if (source.len > NO_INDEX or target.len > NO_INDEX) {
                @panic("ClosestOffsetSumLCS: slice too long for the index type");
            }
            return .{
                .source = source,
                .target = target,
                .source_index = 0,
                .target_index = 0,
            };
        }

        pub fn reset(self: *Self) void {
            self.source_index = 0;
            self.target_index = 0;
        }

        pub fn nextPair(self: *Self) ?Pair {
            if (self.source_index == self.source.len or
                self.target_index == self.target.len)
            {
                return null;
            }

            const value = self.source[self.source_index];
            if (value == self.target[self.target_index]) {
                const pair: Pair = .{
                    .value = value,
                    .source_index = @intCast(self.source_index),
                    .target_index = @intCast(self.target_index),
                };

                self.source_index += 1;
                self.target_index += 1;

                return pair;
            }

            var occurrences: [256]Index = undefined;
            @memset(&occurrences, NO_INDEX);
            for (self.target[self.target_index..], 0..) |item, offset| {
                if (occurrences[item] == NO_INDEX) {
                    occurrences[item] = @intCast(offset);
                }
            }

            var best_sum: usize = std.math.maxInt(usize);
            var best: ?Pair = null;

            for (self.source[self.source_index..], 0..) |item, offset| {
                if (offset >= best_sum) break;

                const stored_target_offset = occurrences[item];
                if (stored_target_offset == NO_INDEX) continue;

                const target_offset: usize = @intCast(stored_target_offset);
                const sum = offset + target_offset;

                if (sum < best_sum) {
                    best_sum = sum;
                    best = .{
                        .value = item,
                        .source_index = @intCast(self.source_index + offset),
                        .target_index = @intCast(self.target_index + target_offset),
                    };
                }
            }

            if (best) |pair| {
                self.source_index = @as(usize, pair.source_index) + 1;
                self.target_index = @as(usize, pair.target_index) + 1;
            }

            return best;
        }

        pub fn next(self: *Self) ?u8 {
            const pair = self.nextPair() orelse return null;
            return pair.value;
        }

        test next {
            var iterator = ClosestOffsetSumLCS(usize).init(&[_]u8{ 2, 1, 0, 3 }, &[_]u8{ 0, 1, 2, 3 });
            try std.testing.expectEqual(@as(?u8, 2), iterator.next());
            try std.testing.expectEqual(@as(?u8, 3), iterator.next());
            try std.testing.expectEqual(@as(?u8, null), iterator.next());
        }

        test nextPair {
            var iterator = ClosestOffsetSumLCS(usize).init(&[_]u8{ 2, 1, 0 }, &[_]u8{ 0, 1, 2 });

            var pair = iterator.nextPair();
            try std.testing.expect(pair != null);
            try std.testing.expectEqual(2, pair.?.value);
            try std.testing.expectEqual(0, pair.?.source_index);
            try std.testing.expectEqual(2, pair.?.target_index);

            pair = iterator.nextPair();
            try std.testing.expectEqual(null, pair);
        }

        test reset {
            var iterator = ClosestOffsetSumLCS(usize).init("abc", "cba");

            try std.testing.expectEqual(@as(?u8, 'a'), iterator.next());
            try std.testing.expectEqual(@as(?u8, null), iterator.next());

            iterator.reset();
            try std.testing.expectEqual(@as(?u8, 'a'), iterator.next());
            try std.testing.expectEqual(@as(?u8, null), iterator.next());
        }

        test "consumed occurrences stay consumed" {
            var iterator = ClosestOffsetSumLCS(usize).init(&[_]u8{ 0, 1, 1 }, &[_]u8{ 1, 0 });
            try std.testing.expectEqual(@as(?u8, 0), iterator.next());
            try std.testing.expectEqual(@as(?u8, null), iterator.next());
        }

        test "pair indices are absolute" {
            var iterator = ClosestOffsetSumLCS(usize).init(&[_]u8{ 7, 8, 7 }, &[_]u8{ 7, 8, 7 });

            const first = iterator.nextPair().?;
            try std.testing.expectEqual(0, first.source_index);
            try std.testing.expectEqual(0, first.target_index);

            const second = iterator.nextPair().?;
            try std.testing.expectEqual(1, second.source_index);
            try std.testing.expectEqual(1, second.target_index);

            const third = iterator.nextPair().?;
            try std.testing.expectEqual(2, third.source_index);
            try std.testing.expectEqual(2, third.target_index);

            try std.testing.expect(iterator.nextPair() == null);
        }

        test "fallback matching preserves absolute indices and reset" {
            const Iterator = ClosestOffsetSumLCS(usize);

            var iterator = Iterator.init(
                &.{ 2, 1, 0, 3 },
                &.{ 0, 1, 2, 3 },
            );

            const expected = [_]Iterator.Pair{
                .{ .value = 2, .source_index = 0, .target_index = 2 },
                .{ .value = 3, .source_index = 3, .target_index = 3 },
            };

            for (0..2) |_| {
                for (expected) |pair| {
                    const actual = iterator.nextPair() orelse
                        return error.ExpectedPair;

                    try std.testing.expectEqualDeep(pair, actual);
                }

                try std.testing.expect(iterator.nextPair() == null);
                try std.testing.expect(iterator.nextPair() == null);

                iterator.reset();
            }
        }
    };
}

pub const CosLcsIterator = ClosestOffsetSumLCS(usize);

const CosLcsPair = extern struct {
    value: u8,
    source_index: usize,
    target_index: usize,
};

const c_allocator = std.heap.c_allocator;

export fn cos_lcs_create(
    source: [*]const u8,
    source_len: usize,
    target: [*]const u8,
    target_len: usize,
) ?*CosLcsIterator {
    const iterator = c_allocator.create(CosLcsIterator) catch return null;
    iterator.* = CosLcsIterator.init(source[0..source_len], target[0..target_len]);
    return iterator;
}

export fn cos_lcs_create_str(source: [*:0]const u8, target: [*:0]const u8) ?*CosLcsIterator {
    return cos_lcs_create(source, std.mem.len(source), target, std.mem.len(target));
}

export fn cos_lcs_destroy(iterator: ?*CosLcsIterator) void {
    const instance = iterator orelse return;
    c_allocator.destroy(instance);
}

export fn cos_lcs_reset(iterator: *CosLcsIterator) void {
    iterator.reset();
}

export fn cos_lcs_next(iterator: *CosLcsIterator, out_value: *u8) bool {
    const value = iterator.next() orelse return false;
    out_value.* = value;
    return true;
}

export fn cos_lcs_next_pair(iterator: *CosLcsIterator, out_pair: *CosLcsPair) bool {
    const pair = iterator.nextPair() orelse return false;
    out_pair.* = .{
        .value = pair.value,
        .source_index = pair.source_index,
        .target_index = pair.target_index,
    };
    return true;
}
