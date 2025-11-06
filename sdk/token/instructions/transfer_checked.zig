//! TransferChecked instruction builder
//!
//! Transfers tokens from one account to another with additional mint and decimals validation.

const std = @import("std");
const types = @import("../../types.zig");
const errors = @import("../../errors.zig");
const cpi = @import("../../cpi.zig");
const token_mod = @import("../mod.zig");

/// Transfer tokens from one account to another with validation
///
/// Accounts:
///   0. `[writable]` Source account
///   1. `[]` Mint account
///   2. `[writable]` Destination account
///   3. `[signer]` Authority (owner or delegate)
pub const TransferChecked = struct {
    /// Source token account
    from: types.AccountInfo,
    /// Mint account
    mint: types.AccountInfo,
    /// Destination token account
    to: types.AccountInfo,
    /// Authority (owner or delegate of source account)
    authority: types.AccountInfo,
    /// Amount of tokens to transfer
    amount: u64,
    /// Number of decimals (must match mint decimals)
    decimals: u8,

    /// Invoke the TransferChecked instruction
    pub fn invoke(self: *const TransferChecked) errors.ProgramError!void {
        return self.invokeSigned(&.{});
    }

    /// Invoke the TransferChecked instruction with PDA signing
    pub fn invokeSigned(self: *const TransferChecked, signers_seeds: []const []const []const u8) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            cpi.AccountMeta.writable(self.from.key()),
            cpi.AccountMeta.readonly(self.mint.key()),
            cpi.AccountMeta.writable(self.to.key()),
            cpi.AccountMeta.signer(self.authority.key()),
        };

        // Build instruction data: [discriminator:1][amount:8][decimals:1]
        var instruction_data: [10]u8 = undefined;
        instruction_data[0] = 12; // discriminator
        std.mem.writeInt(u64, instruction_data[1..9], self.amount, .little);
        instruction_data[9] = self.decimals;

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = &instruction_data,
        };

        // Invoke
        const accounts = [_]types.AccountInfo{ self.from, self.mint, self.to, self.authority };
        try cpi.invokeSigned(&instruction, &accounts, signers_seeds);
    }
};
