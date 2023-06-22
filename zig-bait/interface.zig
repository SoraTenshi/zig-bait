const std = @import("std");

const option = @import("option/option.zig");

const tools = @import("zig-bait-tools");

/// The interface for hooking functions.
pub const Hook = struct {
    const Self = @This();

    /// The option for hooking.
    hook_option: option.Option,

    /// Initialize the interface.
    pub fn init(hook_option: option.Option) Self {
        const self = Self{
            .hook_option = hook_option,
        };

        return self;
    }

    /// Hook the function.
    pub fn do_hook(self: Self) !void {
        switch (self.hook_option) {
            .vmt => |*vmt| try vmt.hook(vmt),
            .safe_vmt => |*safe_vmt| try safe_vmt.hook(safe_vmt),
            .detour => |*detour| try detour.hook(detour),
        }
    }

    /// Restore the function.
    pub fn do_restore(self: Self) !void {
        switch (self.hook_option) {
            .vmt => |*vmt| vmt.restore(vmt),
            .safe_vmt => |*safe_vmt| safe_vmt.restore(safe_vmt),
            .detour => |*detour| detour.restore(detour),
        }
    }
};
