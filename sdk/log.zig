//! Logging utilities for Solana programs

const types = @import("types.zig");
const syscalls = @import("syscalls.zig");

/// Log a message
pub fn log(message: []const u8) void {
    syscalls.log(message);
}

/// Log a single u64 value
pub fn logU64(value: u64) void {
    syscalls.log_u64(value);
}

/// Log 5 u64 values
pub fn log64(arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64) void {
    syscalls.sol_log_64_(arg1, arg2, arg3, arg4, arg5);
}

/// Log a pubkey
pub fn logPubkey(pubkey: *const types.Pubkey) void {
    syscalls.sol_log_pubkey(@as([*]const u8, @ptrCast(pubkey)));
}

/// Log current compute units consumed
pub fn logComputeUnits() void {
    syscalls.logComputeUnits();
}

/// Get remaining compute units
pub fn getRemainingComputeUnits() u64 {
    return syscalls.getRemainingComputeUnits();
}
