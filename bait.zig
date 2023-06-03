// Public utils
pub const vtable_tools = @import("hook/vtable_tools.zig");

// The hook manager
pub usingnamespace @import("hook/hooking_option.zig");

const t = @import("std").testing;
test {
    t.refAllDecls(@This());
}
