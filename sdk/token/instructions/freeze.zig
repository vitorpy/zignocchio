//! FreezeAccount and ThawAccount instruction builders
//!
//! Freeze prevents all token transfers. Thaw re-enables transfers.

const std = @import("std");
const types = @import("../../types.zig");
const errors = @import("../../errors.zig");
const cpi = @import("../../cpi.zig");
const token_mod = @import("../mod.zig");

/// Freeze a token account
///
/// Prevents all transfers from the token account until it is thawed.
/// Only the mint's freeze authority can freeze accounts.
///
/// Accounts:
///   0. `[writable]` Token account to freeze
///   1. `[]` Mint
///   2. `[signer]` Freeze authority
pub const FreezeAccount = struct {
    /// Token account to freeze
    account: types.AccountInfo,
    /// Mint
    mint: types.AccountInfo,
    /// Freeze authority
    freeze_authority: types.AccountInfo,

    /// Invoke the FreezeAccount instruction
    pub fn invoke(self: *const FreezeAccount) errors.ProgramError!void {
        return self.invokeSigned(&.{});
    }

    /// Invoke the FreezeAccount instruction with PDA signing
    pub fn invokeSigned(self: *const FreezeAccount, signers_seeds: []const []const u8) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            .{ .pubkey = self.account.key(), .is_writable = true, .is_signer = false },
            .{ .pubkey = self.mint.key(), .is_writable = false, .is_signer = false },
            .{ .pubkey = self.freeze_authority.key(), .is_writable = false, .is_signer = true },
        };

        // Instruction data: just discriminator (10)
        const instruction_data = [_]u8{10};

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = &instruction_data,
        };

        // Invoke
        const accounts = [_]types.AccountInfo{ self.account, self.mint, self.freeze_authority };
        try cpi.invokeSigned(&instruction, &accounts, signers_seeds);
    }
};

/// Thaw a frozen token account
///
/// Re-enables transfers for a previously frozen token account.
/// Only the mint's freeze authority can thaw accounts.
///
/// Accounts:
///   0. `[writable]` Token account to thaw
///   1. `[]` Mint
///   2. `[signer]` Freeze authority
pub const ThawAccount = struct {
    /// Token account to thaw
    account: types.AccountInfo,
    /// Mint
    mint: types.AccountInfo,
    /// Freeze authority
    freeze_authority: types.AccountInfo,

    /// Invoke the ThawAccount instruction
    pub fn invoke(self: *const ThawAccount) errors.ProgramError!void {
        return self.invokeSigned(&.{});
    }

    /// Invoke the ThawAccount instruction with PDA signing
    pub fn invokeSigned(self: *const ThawAccount, signers_seeds: []const []const u8) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            .{ .pubkey = self.account.key(), .is_writable = true, .is_signer = false },
            .{ .pubkey = self.mint.key(), .is_writable = false, .is_signer = false },
            .{ .pubkey = self.freeze_authority.key(), .is_writable = false, .is_signer = true },
        };

        // Instruction data: just discriminator (11)
        const instruction_data = [_]u8{11};

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = &instruction_data,
        };

        // Invoke
        const accounts = [_]types.AccountInfo{ self.account, self.mint, self.freeze_authority };
        try cpi.invokeSigned(&instruction, &accounts, signers_seeds);
    }
};
