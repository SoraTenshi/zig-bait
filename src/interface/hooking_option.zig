/// The options for the Virtual Method Table hook
pub const VmtOption = struct {
    // The base pointer to the Virtual Function Table
    base: [*c]usize,
    // The index of the function to be hooked
    index: usize,
    // The original Virtual Function Table
    original: [*c]usize,
};

pub const HookingOption = union(enum) {
    vmt_option: VmtOption,
};
