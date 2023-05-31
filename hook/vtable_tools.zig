// Commonly used datatypes
pub const Vtable = [*]align(1) usize;
pub const AbstractClass = *align(1) Vtable;

/// Cast a Object address (containing a vtable) to the AbstractClass type
/// This serves as a convenience wrapper
pub fn addressToVtable(address: usize) AbstractClass {
    return @intToPtr(AbstractClass, address);
}
