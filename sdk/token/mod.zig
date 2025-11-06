//! SPL Token Program support
//!
//! This module provides constants and types for interacting with the SPL Token program.

const std = @import("std");
const types = @import("../types.zig");

// Re-export token state modules
pub const mint = @import("mint.zig");

// Re-export commonly used types
pub const Mint = mint.Mint;

/// SPL Token Program ID: TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA
pub const TOKEN_PROGRAM_ID: types.Pubkey = .{
    0x06, 0xdd, 0xf6, 0xe1, 0xd7, 0x65, 0xa1, 0x93,
    0xd9, 0xcb, 0xe1, 0x46, 0xce, 0xeb, 0x79, 0xac,
    0x1c, 0xb4, 0x85, 0xed, 0x5f, 0x5b, 0x37, 0x91,
    0x3a, 0x8c, 0xf5, 0x85, 0x7e, 0xff, 0x00, 0xa9,
};

/// Account state as stored by the SPL Token program
pub const AccountState = enum(u8) {
    /// Account is not yet initialized
    Uninitialized = 0,
    /// Account is initialized; the account owner and/or delegate may perform permitted operations
    Initialized = 1,
    /// Account has been frozen by the mint freeze authority. Neither the account owner nor
    /// the delegate are able to perform operations on this account.
    Frozen = 2,
};
