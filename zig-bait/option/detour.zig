const std = @import("std");

const Allocator = std.mem.Allocator;

/// The information of the overriden instructions
const ExtractedOperations = struct {
    // The stored prologue
    extracted: []const u8,
    // The address where the stored prologue is located
    address: usize,
};

pub const Detour = struct {
    // The stored operations
    ops: ?ExtractedOperations,
    // The address to the targeted function
    target: usize,
    // The type of the function
    func_ptr_type: type,
    // alloc
    alloc: Allocator,

    pub fn init(alloc: Allocator, target_ptr: anytype) Detour {
        return Detour{
            .ops = null,
            .target = @ptrToInt(target_ptr),
            .function_ptr_type = @TypeOf(target_ptr),
            .alloc = alloc,
        };
    }

    pub fn getOriginalFunction(self: Detour) self.func_ptr_type {
        return @intToPtr(self.func_ptr_type, self.target);
    }

    pub fn deinit(self: *Detour) void {
        self.alloc.free(self.op.extracted);
    }
};
