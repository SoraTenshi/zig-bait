// Public utils
pub const vtable_tools = @import("hook/vtable_tools.zig");

// All the VMT utils
const vmt = @import("hook/vmt.zig");
const safe_vmt = @import("hook/safe_vmt.zig");

const std = @import("std");

const HookingInterface = @import("hook/interface.zig").Hook;
const HookList = std.ArrayList(HookingInterface);

pub const Method = enum {
    vmt,
    safe_vmt,
    currently_unused_detour,
};

pub const HookManager = struct {
    hooks: HookList,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !HookManager {
        return HookManager{
            .hooks = HookList.init(alloc),
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *HookManager) void {
        defer self.hooks.deinit();

        for (self.hooks.items) |item| {
            item.restore(&item.hook_option);
        }
    }

    pub fn restore(self: *HookManager, index: usize) bool {
        if (self.hooks.items.len > index) {
            var target = self.hooks.items[index];
            target.restore(&target.hook_option);
            return true;
        } else {
            return false;
        }
    }

    pub fn append(
        self: *HookManager,
        comptime method: Method,
        object_address: usize,
        comptime positions: []const usize,
        targets: []const usize,
        alloc: std.mem.Allocator,
    ) !void {
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

test {
    const t = @import("std").testing;
    t.refAllDecls(@This());
}
