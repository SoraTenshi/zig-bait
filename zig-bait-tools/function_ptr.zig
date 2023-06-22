const std = @import("std");

pub fn HookFunctionType(comptime option_type: type) type {
    return *const fn (opt: *option_type) anyerror!void;
}

pub fn RestoreFunctionType(comptime option_type: type) type {
    return *const fn (opt: *option_type) void;
}

pub inline fn checkIsFnPtr(fun: anytype) void {
    if (!std.meta.trait.isConstPtr(@TypeOf(fun)) and @typeInfo(@typeInfo(@TypeOf(fun)).Pointer.child) != .Fn) {
        @compileError("Expected fun to be a pointer to a function, got: " ++ @typeName(@TypeOf(fun)));
    }
}
