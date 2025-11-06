//! CloseAccount instruction builder
//!
//! Closes a token account by transferring all remaining lamports to a destination
//! account and zeroing the account data.

const std = @import("std");
const types = @import("../../types.zig");
const errors = @import("../../errors.zig");
const cpi = @import("../../cpi.zig");
const token_mod = @import("../mod.zig");

/// Close a token account
///
/// Closes a token account by transferring all its SOL to the destination account.
/// The token account must have a balance of 0 tokens before it can be closed.
///
/// Accounts:
///   0. `[writable]` Token account to close
///   1. `[writable]` Destination account (receives lamports)
///   2. `[signer]` Authority (owner or close authority)
pub const CloseAccount = struct {
    /// Token account to close
    account: types.AccountInfo,
    /// Destination account (receives remaining lamports)
    destination: types.AccountInfo,
    /// Authority (owner or close authority of token account)
    authority: types.AccountInfo,

    /// Invoke the CloseAccount instruction
    pub fn invoke(self: *const CloseAccount) errors.ProgramError!void {
        return self.invokeSigned(&.{});
    }

    /// Invoke the CloseAccount instruction with PDA signing
    pub fn invokeSigned(self: *const CloseAccount, signers_seeds: []const []const u8) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            .{ .pubkey = self.account.key(), .is_writable = true, .is_signer = false },
            .{ .pubkey = self.destination.key(), .is_writable = true, .is_signer = false },
            .{ .pubkey = self.authority.key(), .is_writable = false, .is_signer = true },
        };

        // Instruction data: just discriminator
        const instruction_data = [_]u8{9};

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = &instruction_data,
        };

        // Invoke
        const accounts = [_]types.AccountInfo{ self.account, self.destination, self.authority };
        try cpi.invokeSigned(&instruction, &accounts, signers_seeds);
    }
};
