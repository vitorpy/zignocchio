//! Hello World - Minimal Zignocchio Example
//!
//! This is the simplest possible Solana program using Zignocchio.

const sdk = @import("sdk/zignocchio.zig");

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
    // Inline the message to prevent .rodata stripping
    const message = [_]u8{ 'H', 'e', 'l', 'l', 'o', ' ', 'f', 'r', 'o', 'm', ' ', 'Z', 'i', 'g', 'n', 'o', 'c', 'c', 'h', 'i', 'o', '!' };
    sdk.logMsg(&message);

    return {};
}
