// Public utils
pub const vtable_tools = @import("hook/vtable_tools.zig");

// All the VMT utils
const vmt = @import("hook/vmt.zig");
const safe_vmt = @import("hook/safe_vmt.zig");

// Func ptr utils
const fn_tool = @import("hook/fn_ptr/func_ptr.zig");

const std = @import("std");

const HookingInterface = @import("hook/interface.zig").Hook;
const HookList = std.ArrayList(HookingInterface);

pub const Method = enum {
    vmt,
    safe_vmt,
    currently_unused_detour,
};

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

    pub fn deinit(self: *Self) void {
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
        fn_tool.checkIfFnPtr(fun);

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
            var target = self.hooks.orderedRemove(found_index);
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
                        vtable_tools.addressToVtable(object_address),
                        positions,
                        targets,
                    ),
                );
            },
            inline .safe_vmt => {
                return self.hooks.append(
                    try safe_vmt.init(
                        vtable_tools.addressToVtable(object_address),
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

const t = @import("std").testing;
test {
    t.refAllDecls(@This());
}

test "safe vmt" {
    t.refAllDecls(safe_vmt);
}

test "hooking option" {
    t.refAllDecls(@import("hook/hooking_option.zig"));
}
