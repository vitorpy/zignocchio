//! Memory allocation for Solana programs

const std = @import("std");
const entrypoint = @import("entrypoint.zig");

/// Bump allocator for Solana programs
///
/// This allocator never frees memory, it only allocates by bumping a pointer.
/// Memory is allocated from high addresses down to low addresses.
pub const BumpAllocator = struct {
    start: usize,
    len: usize,

    const Self = @This();

    /// Create a new bump allocator with default heap settings
    pub fn init() Self {
        return .{
            .start = entrypoint.HEAP_START_ADDRESS,
            .len = entrypoint.HEAP_LENGTH,
        };
    }

    /// Allocate memory
    pub fn alloc(self: *Self, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;

        const pos_ptr = @as(*usize, @ptrFromInt(self.start));
        var pos = pos_ptr.*;

        if (pos == 0) {
            // First allocation - start from top of heap
            pos = self.start + self.len;
        }

        // Align down for the allocation
        const alignment = @as(usize, 1) << @as(std.mem.Allocator.Log2Align, @intCast(ptr_align));
        pos = pos -% len;
        pos &= ~(alignment -% 1);

        // Check if we have space
        if (pos < self.start + @sizeOf(usize)) {
            return null;
        }

        // Update position
        pos_ptr.* = pos;

        return @as([*]u8, @ptrFromInt(pos));
    }

    /// Resize allocation (not supported in bump allocator)
    pub fn resize(self: *Self, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
        _ = self;
        _ = buf;
        _ = buf_align;
        _ = new_len;
        _ = ret_addr;
        return false;
    }

    /// Free memory (no-op for bump allocator)
    pub fn free(self: *Self, buf: []u8, buf_align: u8, ret_addr: usize) void {
        _ = self;
        _ = buf;
        _ = buf_align;
        _ = ret_addr;
        // Bump allocator never frees
    }

    /// Get a std.mem.Allocator interface
    pub fn allocator(self: *Self) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }
};
