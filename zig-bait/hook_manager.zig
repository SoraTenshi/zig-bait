// std
const std = @import("std");

// Public utils
const tools = @import("zig-bait-tools");

// All the VMT utils
const vmt = @import("vmt.zig");
const safe_vmt = @import("safe_vmt.zig");
const detour = @import("detour.zig");

const HookingInterface = @import("interface.zig").Hook;
const HookList = std.ArrayList(HookingInterface);

/// The method of hooking to use
pub const Method = enum {
    vmt,
    safe_vmt,
    detour,
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
    size: usize,

    target_to_index: std.ArrayList(Node),

    /// Init, best used with an Arena allocator
    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .hooks = HookList.init(alloc),
            .alloc = alloc,
            .target_to_index = std.ArrayList(Node).init(alloc),
            .size = 0,
        };
    }

    /// Restore all hooks and deinit the array list
    pub fn deinit(self: *Self) void {
        defer self.hooks.deinit();

        for (self.hooks.items) |*item| {
            item.do_restore();
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
        tools.checkIsFnPtr(fun);

        for (self.hooks.items) |item| {
            const original = switch (item.hook_option) {
                .vmt => |opt| opt.getOriginalFunction(fun, self.getPositionFromTarget(@ptrToInt(fun)) orelse return null) catch null,
                .safe_vmt => |opt| opt.getOriginalFunction(fun, self.getPositionFromTarget(@ptrToInt(fun)) orelse return null) catch null,
                .detour => |opt| opt.getOriginalFunction(fun),
            };

            if (original) |orig| {
                return orig;
            }
        }

        return null;
    }

    /// Hooks only a single function at the specific index
    pub fn hook(self: *Self, comptime index: usize) !void {
        comptime {
            if (index >= self.size) {
                @compileError("Given index out of scope. Is: " ++ std.fmt.fmtIntSizeDec(self.size) ++ " Got: " ++ std.fmt.fmtIntSizeDec(index));
            }
        }

        try self.hooks.items[index].do_hook();
    }

    /// Hooks all the registered functions
    pub fn hookAll(self: *Self) !void {
        for (self.hooks.items) |*h| {
            try h.do_hook();
        }
    }

    /// Restore a hook based on the given hook address
    pub fn restore(self: *Self, target_ptr: usize) bool {
        if (self.getIndexFromTarget(target_ptr)) |found_index| {
            var target = self.hooks.swapRemove(found_index);
            target.do_restore();
            return true;
        } else {
            return false;
        }
    }

    /// Adds a new non-vmt based hook
    pub fn append(
        self: *Self,
        alloc: std.mem.Allocator,
        comptime method: Method,
        victim_address: usize,
        target_ptr: anytype,
    ) !void {
        comptime self.size += 1;
        switch (method) {
            inline .detour => return self.hooks.append(
                try detour.init(
                    alloc,
                    target_ptr,
                    victim_address,
                ),
            ),
            inline else => @compileError("Please call `append_vmt` for vmt based methods instead."),
        }
    }

    /// Adds a new vmt-based hook
    pub fn append_vmt(
        self: *Self,
        alloc: std.mem.Allocator,
        comptime method: Method,
        object_address: usize,
        comptime positions: []const usize,
        targets: []const usize,
    ) !void {
        comptime self.size += 1;
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
                        alloc,
                        tools.addressToVtable(object_address),
                        positions,
                        targets,
                    ),
                );
            },
            inline .safe_vmt => {
                return self.hooks.append(
                    try safe_vmt.init(
                        alloc,
                        tools.addressToVtable(object_address),
                        positions,
                        targets,
                    ),
                );
            },
            inline else => @compileError("Please call `append` for non-vmt based methods instead."),
        }
    }
};

const t = std.testing;
test "safe vmt" {
    t.refAllDecls(safe_vmt);
}
