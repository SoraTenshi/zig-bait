const std = @import("std");

pub inline fn checkIsFnPtr(fun: anytype) void {
    if (!std.meta.trait.isConstPtr(@TypeOf(fun)) and @typeInfo(@typeInfo(@TypeOf(fun)).Pointer.child) != .Fn) {
        @compileError("Expected fun to be a pointer to a function, got: " ++ @typeName(@TypeOf(fun)));
    }
}
