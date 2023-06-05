// Public utils
pub const vtable_tools = @import("zig-bait-tools");

// The hook manager
pub usingnamespace @import("zig-bait/hook_manager.zig");

const t = @import("std").testing;
test {
    t.refAllDecls(@This());
}
