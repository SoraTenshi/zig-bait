// std
const std = @import("std");

// Public utils
const tools = @import("zig-bait-tools");

// All the VMT utils
const vmt = @import("vmt.zig");
const safe_vmt = @import("safe_vmt.zig");

const HookingInterface = @import("interface.zig").Hook;
const HookList = std.ArrayList(HookingInterface);

/// The method of hooking to use
pub const Method = enum {
    vmt,
    safe_vmt,
    currently_unused_detour,
};

/// The hook manager
pub const HookManager = struct {
    const Self = @This();
    const Node = struct {
        position: usize,
        target: usize,
    };

    hooks: HookList,
    alloc: std.mem.Allocator,

    target_to_index: std.ArrayList(Node),

    /// Init, best used with an Arena allocator
    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .hooks = HookList.init(alloc),
            .alloc = alloc,
            .target_to_index = std.ArrayList(Node).init(alloc),
        };
    }

    /// Restore all hooks and deinit the array list
    pub fn deinit(self: *Self) void {
        defer self.hooks.deinit();

        for (self.hooks.items) |*item| {
            item.restore(&item.hook_option);
        }
    }

    /// Gets the index from the address of the hook address
    pub fn getPositionFromTarget(self: Self, target: usize) ?usize {
        for (self.target_to_index.items) |item| {
            if (item.target == target) {
                return item.position;
            }
        }

        return null;
    }

    /// Gets the index from the address of the hook address
    fn getIndexFromTarget(self: Self, target: usize) ?usize {
        for (self.target_to_index.items, 0..) |item, i| {
            if (item.target == target) {
                return i;
            }
        }

        return null;
    }

    /// Gets the original function pointer to call
    pub fn getOriginalFunction(self: Self, fun: anytype) ?@TypeOf(fun) {
        std.meta.trait.isPtrTo(.Fn)(fun);

        for (self.hooks.items) |item| {
            const original = switch (item.hook_option) {
                .vmt_option => |opt| opt.getOriginalFunction(fun, self.getPositionFromTarget(@ptrToInt(fun)) orelse return null) catch null,
            };

            if (original) |orig| {
                return orig;
            }
        }

        return null;
    }

    /// Restore a hook based on the given hook address
    pub fn restore(self: *Self, target_ptr: usize) bool {
        if (self.getIndexFromTarget(target_ptr)) |found_index| {
            var target = self.hooks.swapRemove(found_index);
            target.restore(&target.hook_option);
            return true;
        } else {
            return false;
        }
    }

    /// Adds a new hook
    pub fn append(
        self: *Self,
        comptime method: Method,
        object_address: usize,
        comptime positions: []const usize,
        targets: []const usize,
        alloc: std.mem.Allocator,
    ) !void {
        for (positions, targets) |pos, ptr| {
            try self.target_to_index.append(Node{
                .position = pos,
                .target = ptr,
            });
        }

        switch (method) {
            inline .vmt => {
                return self.hooks.append(
                    try vmt.init(
                        tools.addressToVtable(object_address),
                        positions,
                        targets,
                    ),
                );
            },
            inline .safe_vmt => {
                return self.hooks.append(
                    try safe_vmt.init(
                        tools.addressToVtable(object_address),
                        positions,
                        targets,
                        alloc,
                    ),
                );
            },
            inline .currently_unused_detour => @compileError("Detour hooks are unfortunately not yet supported."),
        }
    }
};

const t = std.testing;
test "safe vmt" {
    t.refAllDecls(safe_vmt);
}
