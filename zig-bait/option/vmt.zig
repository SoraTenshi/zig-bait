const std = @import("std");
const Allocator = std.mem.Allocator;

const AbstractClass = @import("zig-bait-tools").AbstractClass;

/// The mapping from index to target as well as restore address
const IndexToTarget = struct {
    position: usize,
    target: usize,
    restore: ?usize,
};

/// The VMT option type
pub const VmtOption = struct {
    /// The base class containing the targeted VTable
    base: AbstractClass,
    /// The mapping from index to target as well as restore values
    index_map: []IndexToTarget,
    /// The allocator used to allocate the index map
    alloc: Allocator,

    /// Initialize the VMT option
    /// remarks: The allocator will be wrapped in an ArenaAllocator
    pub fn init(alloc: Allocator, base: AbstractClass, comptime positions: []const usize, targets: []const usize) VmtOption {
        var arena = std.heap.ArenaAllocator.init(alloc);
        var self = VmtOption{
            .base = base,
            .index_map = arena.allocator().alloc(IndexToTarget, positions.len) catch @panic("OOM"),
            .alloc = arena,
        };

        for (positions, 0..) |pos, i| {
            self.index_map[i] = IndexToTarget{
                .position = pos,
                .target = targets[i],
                .restore = null,
            };
        }

        return self;
    }

    /// Gets the original function at the given position
    pub fn getOriginalFunction(self: VmtOption, hooked_func: anytype, position: usize) anyerror!@TypeOf(hooked_func) {
        std.meta.trait.isPtrTo(.Fn)(hooked_func);

        for (self.index_map) |map| {
            if (map.position == position) {
                return @intToPtr(@TypeOf(hooked_func), map.restore.?);
            }
        }

        return error.InvalidPosition;
    }

    /// Deinit the option
    pub fn deinit(self: *VmtOption) void {
        self.alloc.deinit();
    }
};
