pub const vmt = @import("vmt.zig");
pub const safe_vmt = @import("safe_vmt.zig");
pub const detour = @import("detour.zig");

// The option enum for the different hook options
pub const Option = union(enum) {
    // The "normal" vmt hook
    vmt: vmt.Option,
    // The "safe" vmt hook
    safe_vmt: safe_vmt.Option,
    // The detour hook
    detour: detour.Option,
};
