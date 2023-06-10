const std = @import("std");

pub inline fn checkIsFnPtr(fun: anytype) void {
    if (!std.meta.trait.isPtrTo(.Fn)(@TypeOf(fun))) {
        @compileError("Expected fun to be a pointer to a function, got: " ++ @typeName(@TypeOf(fun)));
    }
}
