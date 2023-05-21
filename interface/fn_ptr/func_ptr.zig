const std = @import("std");

pub inline fn checkIfFnPtr(candidate: anytype) void {
    comptime {
        if (@typeInfo(@typeInfo(@TypeOf(candidate)).Pointer.child) != .Fn) {
            @compileError("expected 'candidate' to be a function ptr, but got " ++ @typeName(@TypeOf(candidate)));
        }
    }
}
