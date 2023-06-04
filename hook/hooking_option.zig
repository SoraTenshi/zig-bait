const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const AbstractClass = @import("vtable_tools.zig").AbstractClass;

const IndexToTarget = struct {
    position: usize,
    target: usize,
    restore: ?usize,
};

/// The options for the Virtual Method Table hook
pub const VmtOption = struct {
    /// The base class containing the targeted VTable
    base: AbstractClass,
    /// The mapping from index to target as well as restore values
    index_map: []IndexToTarget,
    /// Whether the vtable shall be copied and the original pointer be redirected, or if only functions should be swapped
    safe: bool,
    /// The original vtable pointer
    safe_orig: ?usize,
    /// The allocator to be used when `shadow` is enabled
    alloc: ?std.heap.ArenaAllocator,
    /// Track of the vtable
    created_vtable: ?[]usize,

    pub fn init(base: AbstractClass, comptime positions: []const usize, targets: []const usize, alloc: Allocator) VmtOption {
        var arena = std.heap.ArenaAllocator.init(alloc);
        var self = VmtOption{
            .base = base,
            .index_map = arena.allocator().alloc(IndexToTarget, positions.len) catch @panic("OOM"),
            .safe = false,
            .safe_orig = null,
            .alloc = arena,
            .created_vtable = null,
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

    /// Uses a ArenaAllocator to manage the memory
    pub fn initSafe(base: AbstractClass, comptime positions: []const usize, targets: []const usize, alloc: Allocator) VmtOption {
        var arena = std.heap.ArenaAllocator.init(alloc);
        var self = VmtOption{
            .base = base,
            .index_map = arena.allocator().alloc(IndexToTarget, positions.len) catch @panic("OOM"),
            .safe = false,
            .safe_orig = null,
            .alloc = arena,
            .created_vtable = null,
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

    pub fn getOriginalFunction(self: VmtOption, hooked_func: anytype, position: usize) anyerror!@TypeOf(hooked_func) {
        std.meta.trait.isPtrTo(.Fn)(hooked_func);

        for (self.index_map) |map| {
            if (map.position == position) {
                return @intToPtr(@TypeOf(hooked_func), map.restore.?);
            }
        }

        return error.InvalidPosition;
    }

    pub fn deinit(self: *VmtOption) void {
        if (self.alloc) |alloc| {
            alloc.deinit();
        }
    }
};

pub const HookingOption = union(enum) {
    vmt_option: VmtOption,
};
