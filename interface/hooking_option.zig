const fn_ptr = @import("fn_ptr/func_ptr.zig");

/// The options for the Virtual Method Table hook
pub const VmtOption = struct {
    // The base pointer to the Virtual Function Table
    base: [*]usize,
    // The index of the function to be hooked
    index: usize,
    // The target that should be hooked
    target: usize,
    // The restore address. used internally.
    restore: ?usize,
    // Whether to use debug logging
    debug: bool,
    // Vtable length
    fn_length: ?usize,

    pub fn init(base: [*]usize, index: usize, target: usize, fn_length: ?usize) VmtOption {
        return VmtOption{
            .base = base,
            .index = index,
            .target = target,
            .restore = null,
            .debug = false,
            .fn_length = fn_length,
        };
    }

    pub fn getOriginalFunction(self: VmtOption, hooked_func: anytype) anyerror!@TypeOf(hooked_func) {
        fn_ptr.checkIfFnPtr(hooked_func);

        if (self.restore) |restore| {
            return @intToPtr(@TypeOf(hooked_func), restore);
        } else {
            return error.RestoreValueIsNull;
        }
    }
};

pub const HookingOption = union(enum) {
    vmt_option: VmtOption,
};
