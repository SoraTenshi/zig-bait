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

    pub fn init(base: [*]usize, index: usize, target: usize) VmtOption {
        return VmtOption{
            .base = base,
            .index = index,
            .target = target,
            .restore = null,
        };
    }
};

pub const HookingOption = union(enum) {
    vmt_option: VmtOption,
};
