const std = @import("std");
const Allocator = std.mem.Allocator;

const tools = @import("zig-bait-tools");
const AbstractClass = tools.AbstractClass;

/// The mapping from index to target as well as restore address
const IndexToTarget = struct {
    position: usize,
    target: usize,
    restore: ?usize,
};

pub const HookFunc = tools.HookFunctionType(Option);
pub const RestoreFunc = tools.RestoreFunctionType(Option);

/// The VMT option type
pub const Option = struct {
    /// The base class containing the targeted VTable
    base: AbstractClass,
    /// The mapping from index to target as well as restore values
    index_map: []IndexToTarget,
    /// The allocator used to allocate the index map
    alloc: Allocator,
    /// The hook function
    hook: HookFunc,
    /// The restore function
    restore: RestoreFunc,

    /// Initialize the VMT option
    /// remarks: The allocator will be wrapped in an ArenaAllocator
    pub fn init(
        alloc: Allocator,
        base: AbstractClass,
        comptime positions: []const usize,
        targets: []const usize,
        hook: HookFunc,
        restore: RestoreFunc,
    ) !Option {
        var arena = std.heap.ArenaAllocator.init(alloc);
        var self = Option{
            .base = base,
            .index_map = try arena.allocator().alloc(IndexToTarget, positions.len),
            .alloc = arena,
            .hook = hook,
            .restore = restore,
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
    pub fn getOriginalFunction(self: Option, hooked_func: anytype, position: usize) anyerror!@TypeOf(hooked_func) {
        tools.checkIsFnPtr(hooked_func);

        for (self.index_map) |map| {
            if (map.position == position) {
                return @intToPtr(@TypeOf(hooked_func), map.restore.?);
            }
        }

        return error.InvalidPosition;
    }

    /// Deinit the option
    pub fn deinit(self: *Option) void {
        self.alloc.deinit();
    }
};
