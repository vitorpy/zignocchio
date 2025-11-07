//! SyncNative instruction builder
//!
//! Updates a native token account's balance to match its wrapped SOL lamports.
//! Only applicable to native token accounts (wrapped SOL).

const std = @import("std");
const types = @import("../../types.zig");
const errors = @import("../../errors.zig");
const cpi = @import("../../cpi.zig");
const token_mod = @import("../mod.zig");

/// Sync native token account balance
///
/// Updates the token account's amount field to match its current lamport balance.
/// This is only applicable to native token accounts (wrapped SOL).
///
/// Accounts:
///   0. `[writable]` Native token account to sync
pub const SyncNative = struct {
    /// Native token account to sync
    account: types.AccountInfo,

    /// Invoke the SyncNative instruction
    pub fn invoke(self: *const SyncNative) errors.ProgramError!void {
        return self.invokeSigned(&.{});
    }

    /// Invoke the SyncNative instruction with PDA signing
    pub fn invokeSigned(self: *const SyncNative, signers_seeds: []const []const u8) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            .{ .pubkey = self.account.key(), .is_writable = true, .is_signer = false },
        };

        // Instruction data: just discriminator (17)
        const instruction_data = [_]u8{17};

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = &instruction_data,
        };

        // Invoke
        const accounts = [_]types.AccountInfo{self.account};
        try cpi.invokeSigned(&instruction, &accounts, signers_seeds);
    }
};
