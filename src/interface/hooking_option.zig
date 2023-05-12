pub const VmtOption = struct {
    base: *[*c]usize,
    offset: usize,
    index: usize,
    original: ?usize,
};

pub const HookingOption = union(enum) {
    vmt_option: VmtOption,
};
