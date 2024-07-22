const std = @import("std");
const Allocator = std.mem.Allocator;

const tools = @import("zig-bait-tools");
const AbstractClass = tools.AbstractClass;

const IndexToTarget = struct {
    position: usize,
    target: usize,
    restore: ?usize,
};

pub const HookFunc = tools.HookFunctionType(Option);
pub const RestoreFunc = tools.RestoreFunctionType(Option);

/// The options for the Virtual Method Table hook
pub const Option = struct {
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
    /// The hook function
    hook: HookFunc,
    /// The restore function
    restore: RestoreFunc,

    fn lessThan(_: void, lhs: IndexToTarget, rhs: IndexToTarget) bool {
        return lhs.position < rhs.position;
    }

    /// Initialize the VMT hooking option
    pub fn init(
        alloc: Allocator,
        base: AbstractClass,
        positions: []const usize,
        targets: []const usize,
        hook: HookFunc,
        restore: RestoreFunc,
    ) !Option {
        var arena = std.heap.ArenaAllocator.init(alloc);
        var self = Option{
            .base = base,
            .index_map = try arena.allocator().alloc(IndexToTarget, positions.len),
            .safe_orig = null,
            .alloc = arena,
            .created_vtable = null,
            .hook = hook,
            .restore = restore,
        };

        // Initialize the index map
        for (positions, 0..) |pos, i| {
            self.index_map[i] = IndexToTarget{
                .position = pos,
                .target = targets[i],
                .restore = null,
            };
        }

        std.sort.insertion(IndexToTarget, self.index_map, {}, lessThan);

        return self;
    }

    /// Return the function pointer of the hooked function
    pub fn getOriginalFunction(self: Option, hooked_func: anytype, position: usize) anyerror!@TypeOf(hooked_func) {
        tools.checkIsFnPtr(hooked_func);

        for (self.index_map) |map| {
            if (map.position == position) {
                return @as(@TypeOf(hooked_func), @ptrFromInt(map.restore.?));
            }
        }

        return error.InvalidPosition;
    }

    // Deinitialize the VMT hooking option
    pub fn deinit(self: *Option) void {
        if (self.alloc) |alloc| {
            alloc.deinit();
        }
    }
};
