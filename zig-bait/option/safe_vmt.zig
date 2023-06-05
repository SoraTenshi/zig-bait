const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const AbstractClass = @import("zig-bait-tools").AbstractClass;

const IndexToTarget = struct {
    position: usize,
    target: usize,
    restore: ?usize,
};

/// The options for the Virtual Method Table hook
pub const SafeVmtOption = struct {
    /// The base class containing the targeted VTable
    base: AbstractClass,
    /// The mapping from index to target as well as restore values
    index_map: []IndexToTarget,
    /// The original vtable pointer
    safe_orig: ?usize,
    /// The allocator to be used when `shadow` is enabled
    alloc: ?std.heap.ArenaAllocator,
    /// Track of the vtable
    created_vtable: ?[]usize,

    /// Initialize the VMT hooking option
    pub fn init(base: AbstractClass, comptime positions: []const usize, targets: []const usize, alloc: Allocator) SafeVmtOption {
        var arena = std.heap.ArenaAllocator.init(alloc);
        var self = SafeVmtOption{
            .base = base,
            .index_map = arena.allocator().alloc(IndexToTarget, positions.len) catch @panic("OOM"),
            .safe_orig = null,
            .alloc = arena,
            .created_vtable = null,
        };

        // Initialize the index map
        for (positions, 0..) |pos, i| {
            self.index_map[i] = IndexToTarget{
                .position = pos,
                .target = targets[i],
                .restore = null,
            };
        }

        return self;
    }

    /// Return the function pointer of the hooked function
    pub fn getOriginalFunction(self: SafeVmtOption, hooked_func: anytype, position: usize) anyerror!@TypeOf(hooked_func) {
        std.meta.trait.isPtrTo(.Fn)(hooked_func);

        for (self.index_map) |map| {
            if (map.position == position) {
                return @intToPtr(@TypeOf(hooked_func), map.restore.?);
            }
        }

        return error.InvalidPosition;
    }

    // Deinitialize the VMT hooking option
    pub fn deinit(self: *SafeVmtOption) void {
        if (self.alloc) |alloc| {
            alloc.deinit();
        }
    }
};
