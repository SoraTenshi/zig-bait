/// Vtable utilities
const vtable = @import("vtable.zig");
pub const Vtable = vtable.Vtable;
pub const AbstractClass = vtable.AbstractClass;
pub const addressToVtable = vtable.addressToVtable;

/// Protection utilities
const protect = @import("protect.zig");
pub const Address = protect.Address;
pub const Flags = protect.Flags;
pub const getFlags = protect.getFlags;
pub const setNewProtect = protect.setNewProtect;

/// Function utilities
const fn_ptr = @import("function_ptr.zig");
pub const HookFunctionType = fn_ptr.HookFunctionType;
pub const RestoreFunctionType = fn_ptr.RestoreFunctionType;
pub const checkIsFnPtr = fn_ptr.checkIsFnPtr;

/// Opcodes
const assembler = @import("assembler.zig");
pub const Opcodes = assembler.Opcodes;
pub const Register = assembler.Register;
pub const ptrSize = assembler.ptrSize;
pub const addressToBytes = assembler.addressToBytes;
