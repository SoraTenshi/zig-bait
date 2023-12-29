const std = @import("std");

pub fn HookFunctionType(comptime option_type: type) type {
    return *const fn (opt: *option_type) anyerror!void;
}

pub fn RestoreFunctionType(comptime option_type: type) type {
    return *const fn (opt: *option_type) void;
}

pub inline fn checkIsFnPtr(fun: anytype) void {
    switch (@typeInfo(@TypeOf(fun))) {
        .Pointer => |ptr| {
            switch (@typeInfo(ptr.child)) {
                .Fn => {},
                else => @compileError("Expected fun to be a pointer to a function, got: " ++ @typeName(@TypeOf(fun))),
            }
        },
        else => @compileError("Expected fun to be a pointer to a function, got: " ++ @typeName(@TypeOf(fun))),
    }
}
