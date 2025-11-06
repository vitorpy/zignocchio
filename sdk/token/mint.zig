//! SPL Token Mint state structure
//!
//! This module provides the Mint struct and related functionality for working with
//! SPL Token mint accounts.

const std = @import("std");
const types = @import("../types.zig");
const errors = @import("../errors.zig");
const token_mod = @import("mod.zig");

/// Mint account data (82 bytes)
///
/// Memory layout matches SPL Token exactly:
/// - mint_authority_flag: 4 bytes (0 for None, 1 for Some)
/// - mint_authority: 32 bytes
/// - supply: 8 bytes (little-endian u64)
/// - decimals: 1 byte
/// - is_initialized: 1 byte (0 or 1)
/// - freeze_authority_flag: 4 bytes (0 for None, 1 for Some)
/// - freeze_authority: 32 bytes
pub const Mint = extern struct {
    /// Indicates whether the mint authority is present (1) or not (0)
    mint_authority_flag: [4]u8,

    /// Optional authority used to mint new tokens
    mint_authority: types.Pubkey,

    /// Total supply of tokens (little-endian)
    supply_bytes: [8]u8,

    /// Number of base 10 digits to the right of the decimal place
    decimals_value: u8,

    /// Is 1 if this structure has been initialized
    is_initialized_flag: u8,

    /// Indicates whether the freeze authority is present (1) or not (0)
    freeze_authority_flag: [4]u8,

    /// Optional authority to freeze token accounts
    freeze_authority: types.Pubkey,

    /// The length of the Mint account data
    pub const LEN: usize = 82;

    /// Load a Mint from account info with validation
    ///
    /// Validates:
    /// - Account data length is exactly 82 bytes
    /// - Account is owned by the Token Program
    pub fn fromAccountInfo(account: types.AccountInfo) errors.ProgramError!*const Mint {
        // Check length
        if (account.dataLen() != LEN) {
            return error.InvalidAccountData;
        }

        // Check owner
        if (!types.pubkeyEq(account.owner(), &token_mod.TOKEN_PROGRAM_ID)) {
            return error.IncorrectProgramId;
        }

        // Get data and cast to Mint
        const data = account.borrowDataUnchecked();
        return @ptrCast(@alignCast(data.ptr));
    }

    /// Get the mint authority if present
    pub fn mintAuthority(self: *const Mint) ?*const types.Pubkey {
        if (self.mint_authority_flag[0] == 1) {
            return &self.mint_authority;
        }
        return null;
    }

    /// Get the total supply of tokens
    pub fn supply(self: *const Mint) u64 {
        return std.mem.readInt(u64, &self.supply_bytes, .little);
    }

    /// Get the number of decimals
    pub fn decimals(self: *const Mint) u8 {
        return self.decimals_value;
    }

    /// Check if the mint is initialized
    pub fn isInitialized(self: *const Mint) bool {
        return self.is_initialized_flag == 1;
    }

    /// Get the freeze authority if present
    pub fn freezeAuthority(self: *const Mint) ?*const types.Pubkey {
        if (self.freeze_authority_flag[0] == 1) {
            return &self.freeze_authority;
        }
        return null;
    }
};

// Compile-time assertion to ensure struct size is exactly 82 bytes
comptime {
    if (@sizeOf(Mint) != 82) {
        @compileError("Mint struct must be exactly 82 bytes");
    }
}
