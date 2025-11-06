//! Helper module - simulates sdk/token/instructions pattern
//!
//! This module imports TOKEN_PROGRAM_ID from constants.zig
//! and uses it, replicating the SDK structure.

const sdk = @import("sdk");
const constants = @import("constants.zig");

/// Check if a pubkey matches TOKEN_PROGRAM_ID (simulates SDK instruction builders)
pub fn isTokenProgram(pubkey: *const sdk.Pubkey) bool {
    return sdk.pubkeyEq(pubkey, &constants.TOKEN_PROGRAM_ID);
}

/// Check if a pubkey matches SYSTEM_PROGRAM_ID
pub fn isSystemProgram(pubkey: *const sdk.Pubkey) bool {
    return sdk.pubkeyEq(pubkey, &constants.SYSTEM_PROGRAM_ID);
}

/// Build instruction data using TOKEN_PROGRAM_ID (simulates instruction builders)
pub fn buildInstructionData(buffer: []u8) void {
    // Copy TOKEN_PROGRAM_ID into buffer (like SDK does for CPI instructions)
    @memcpy(buffer[0..32], &constants.TOKEN_PROGRAM_ID);
}
