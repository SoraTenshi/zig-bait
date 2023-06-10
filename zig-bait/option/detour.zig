const std = @import("std");

const tools = @import("zig-bait-tools");

const Allocator = std.mem.Allocator;

const bitHigh = if (tools.ptrSize == 8) 1 else 0; // 64 bit requires an additional byte
const requiredSize = bitHigh + 3 + tools.ptrSize;

/// The information of the overriden instructions
pub const ExtractedOperations = struct {
    // The stored prologue
    extracted: []const u8,
    // The address where the stored prologue is located
    address: usize,

    pub fn init(alloc: Allocator, shellcode_size: usize) !ExtractedOperations {
        const extracted = try alloc.alloc(u8, shellcode_size);
        return ExtractedOperations{
            .extracted = extracted,
            .address = @ptrToInt(extracted.ptr),
        };
    }
};

pub const DetourOption = struct {
    // The stored operations
    ops: ?ExtractedOperations,
    // The address to the targeted function
    target: usize,
    // The address of the victim function
    victim: usize,
    // address to the after-jump location
    after_jump: usize,
    // alloc
    alloc: Allocator,

    pub fn init(alloc: Allocator, target_ptr: anytype, victim_address: usize) DetourOption {
        return DetourOption{
            .ops = null,
            .target = @ptrToInt(target_ptr),
            .victim = victim_address,
            .after_jump = victim_address + requiredSize,
            .alloc = alloc,
        };
    }

    pub fn getOriginalFunction(self: DetourOption, original_func: anytype) @TypeOf(original_func) {
        return @intToPtr(original_func, self.after_jump);
    }

    pub fn deinit(self: *DetourOption) void {
        self.alloc.free(self.op.extracted);
    }
};
