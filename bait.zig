// Public utils
pub const addressToVtable = @import("zig-bait-tools").addressToVtable;

// The hook manager
pub const HookManager = @import("zig-bait/hook_manager.zig").HookManager;

test "hook manager tests" {
    @import("std").testing.refAllDecls(@import("zig-bait/hook_manager.zig"));
}
