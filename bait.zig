// Public utils
pub const addressToVtable = @import("zig-bait-tools").addressToVtable;

// The hook manager
pub usingnamespace @import("zig-bait/hook_manager.zig");

test "hook manager tests" {
    @import("std").testing.refAllDecls(@import("zig-bait/hook_manager.zig"));
}
