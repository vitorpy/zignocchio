//! Hello World - Minimal Zignocchio Example
//!
//! This is the simplest possible Solana program using Zignocchio.

const sdk = @import("sdk");

/// Program entrypoint
export fn entrypoint(input: [*]u8) u64 {
    return @call(.always_inline, sdk.createEntrypointWithMaxAccounts(1, processInstruction), .{input});
}

/// Process instruction
fn processInstruction(
    _: *const sdk.Pubkey,
    _: []sdk.AccountInfo,
    _: []const u8,
) sdk.ProgramResult {
    sdk.logMsg("Hello from Zignocchio!");
    return {};
}
