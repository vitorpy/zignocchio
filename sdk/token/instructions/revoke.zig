//! Revoke instruction builder
//!
//! Removes delegate authority from a token account.

const std = @import("std");
const types = @import("../../types.zig");
const errors = @import("../../errors.zig");
const cpi = @import("../../cpi.zig");
const token_mod = @import("../mod.zig");

/// Revoke delegate authority from a token account
///
/// Removes the delegate's authority to transfer tokens from the account.
/// After revocation, only the account owner can transfer tokens.
///
/// Accounts:
///   0. `[writable]` Token account
///   1. `[signer]` Owner of the token account
pub const Revoke = struct {
    /// Token account to revoke delegate from
    source: types.AccountInfo,
    /// Owner of the token account
    owner: types.AccountInfo,

    /// Invoke the Revoke instruction
    pub fn invoke(self: *const Revoke) errors.ProgramError!void {
        return self.invokeSigned(&.{});
    }

    /// Invoke the Revoke instruction with PDA signing
    pub fn invokeSigned(self: *const Revoke, signers_seeds: []const []const u8) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            .{ .pubkey = self.source.key(), .is_writable = true, .is_signer = false },
            .{ .pubkey = self.owner.key(), .is_writable = false, .is_signer = true },
        };

        // Instruction data: just discriminator (5)
        const instruction_data = [_]u8{5};

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = &instruction_data,
        };

        // Invoke
        const accounts = [_]types.AccountInfo{ self.source, self.owner };
        try cpi.invokeSigned(&instruction, &accounts, signers_seeds);
    }
};
