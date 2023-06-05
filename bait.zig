// Public utils
pub const addressToVtable = @import("zig-bait-tools").addressToVtable;

// The hook manager
pub usingnamespace @import("zig-bait/hook_manager.zig");

const t = @import("std").testing;
test {
    t.refAllDecls(@This());
}
