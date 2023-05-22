// All the VMT utils
pub const vmt = @import("interface/vmt.zig");

const HookingInterface = @import("interface/interface.zig").Hook;

pub const HookArrayList = @import("std").ArrayList(HookingInterface);
pub var global_hooks: ?HookArrayList = null;

pub fn restore(index: usize) void {
    var target = global_hooks.?.items[index];
    target.restore(&target.hook_option);
}

pub fn restoreAll() void {
    if (global_hooks) |hooks| {
        for (hooks.items) |*t| {
            t.restore(&t.hook_option);
        }
    }
}
