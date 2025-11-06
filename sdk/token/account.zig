//! SPL Token Account state structure
//!
//! This module provides the TokenAccount struct and related functionality for working with
//! SPL Token account data.

const std = @import("std");
const types = @import("../types.zig");
const errors = @import("../errors.zig");
const token_mod = @import("mod.zig");

/// Token account data (165 bytes)
///
/// Memory layout matches SPL Token exactly:
/// - mint: 32 bytes
/// - owner: 32 bytes
/// - amount: 8 bytes (little-endian u64)
/// - delegate_flag: 4 bytes (0 for None, 1 for Some)
/// - delegate: 32 bytes
/// - state: 1 byte (AccountState enum)
/// - is_native_flag: 4 bytes (0 for None, 1 for Some)
/// - native_amount: 8 bytes (little-endian u64)
/// - delegated_amount: 8 bytes (little-endian u64)
/// - close_authority_flag: 4 bytes (0 for None, 1 for Some)
/// - close_authority: 32 bytes
pub const TokenAccount = extern struct {
    /// The mint associated with this account
    mint_pubkey: types.Pubkey,

    /// The owner of this account
    owner_pubkey: types.Pubkey,

    /// The amount of tokens this account holds (little-endian)
    amount_bytes: [8]u8,

    /// Indicates whether the delegate is present (1) or not (0)
    delegate_flag: [4]u8,

    /// Optional delegate authorized to transfer/burn tokens
    delegate_pubkey: types.Pubkey,

    /// The account's state (Uninitialized/Initialized/Frozen)
    state_value: u8,

    /// Indicates whether this is a native token (1) or not (0)
    is_native_flag: [4]u8,

    /// Rent-exempt reserve for native tokens (little-endian)
    native_amount_bytes: [8]u8,

    /// The amount delegated (little-endian)
    delegated_amount_bytes: [8]u8,

    /// Indicates whether the close authority is present (1) or not (0)
    close_authority_flag: [4]u8,

    /// Optional authority to close the account
    close_authority_pubkey: types.Pubkey,

    /// The length of the TokenAccount data
    pub const LEN: usize = 165;

    /// Load a TokenAccount from account info with validation
    ///
    /// Validates:
    /// - Account data length is exactly 165 bytes
    /// - Account is owned by the Token Program
    pub fn fromAccountInfo(account: types.AccountInfo) errors.ProgramError!*const TokenAccount {
        // Check length
        if (account.dataLen() != LEN) {
            return error.InvalidAccountData;
        }

        // Check owner
        if (!types.pubkeyEq(account.owner(), &token_mod.TOKEN_PROGRAM_ID)) {
            return error.IncorrectProgramId;
        }

        // Get data and cast to TokenAccount
        const data = account.borrowDataUnchecked();
        return @ptrCast(@alignCast(data.ptr));
    }

    /// Get the mint pubkey
    pub fn mint(self: *const TokenAccount) *const types.Pubkey {
        return &self.mint_pubkey;
    }

    /// Get the owner pubkey
    pub fn owner(self: *const TokenAccount) *const types.Pubkey {
        return &self.owner_pubkey;
    }

    /// Get the token amount
    pub fn amount(self: *const TokenAccount) u64 {
        return std.mem.readInt(u64, &self.amount_bytes, .little);
    }

    /// Get the delegate if present
    pub fn delegate(self: *const TokenAccount) ?*const types.Pubkey {
        if (self.delegate_flag[0] == 1) {
            return &self.delegate_pubkey;
        }
        return null;
    }

    /// Get the account state
    pub fn state(self: *const TokenAccount) token_mod.AccountState {
        return @enumFromInt(self.state_value);
    }

    /// Check if this is a native token account
    pub fn isNative(self: *const TokenAccount) bool {
        return self.is_native_flag[0] == 1;
    }

    /// Get the native amount (rent-exempt reserve) if this is a native token
    pub fn nativeAmount(self: *const TokenAccount) ?u64 {
        if (self.isNative()) {
            return std.mem.readInt(u64, &self.native_amount_bytes, .little);
        }
        return null;
    }

    /// Get the delegated amount
    pub fn delegatedAmount(self: *const TokenAccount) u64 {
        return std.mem.readInt(u64, &self.delegated_amount_bytes, .little);
    }

    /// Get the close authority if present
    pub fn closeAuthority(self: *const TokenAccount) ?*const types.Pubkey {
        if (self.close_authority_flag[0] == 1) {
            return &self.close_authority_pubkey;
        }
        return null;
    }

    /// Check if the account is initialized
    pub fn isInitialized(self: *const TokenAccount) bool {
        return self.state_value != @intFromEnum(token_mod.AccountState.Uninitialized);
    }

    /// Check if the account is frozen
    pub fn isFrozen(self: *const TokenAccount) bool {
        return self.state_value == @intFromEnum(token_mod.AccountState.Frozen);
    }
};

// Compile-time assertion to ensure struct size is exactly 165 bytes
comptime {
    if (@sizeOf(TokenAccount) != 165) {
        @compileError("TokenAccount struct must be exactly 165 bytes");
    }
}
