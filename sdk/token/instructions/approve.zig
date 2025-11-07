//! Approve and ApproveChecked instruction builders
//!
//! Delegates authority to transfer tokens from a token account.

const std = @import("std");
const types = @import("../../types.zig");
const errors = @import("../../errors.zig");
const cpi = @import("../../cpi.zig");
const token_mod = @import("../mod.zig");

/// Approve a delegate to transfer tokens
///
/// Authorizes a delegate to transfer up to a specified amount of tokens
/// from the source account. The delegate can make multiple transfers
/// until the total reaches the approved amount.
///
/// Accounts:
///   0. `[writable]` Token account to approve delegate for
///   1. `[]` Delegate account
///   2. `[signer]` Owner of the token account
pub const Approve = struct {
    /// Token account (source)
    source: types.AccountInfo,
    /// Delegate account
    delegate: types.AccountInfo,
    /// Owner of the source account
    owner: types.AccountInfo,
    /// Amount the delegate is approved to transfer
    amount: u64,

    /// Invoke the Approve instruction
    pub fn invoke(self: *const Approve) errors.ProgramError!void {
        return self.invokeSigned(&.{});
    }

    /// Invoke the Approve instruction with PDA signing
    pub fn invokeSigned(self: *const Approve, signers_seeds: []const []const u8) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            .{ .pubkey = self.source.key(), .is_writable = true, .is_signer = false },
            .{ .pubkey = self.delegate.key(), .is_writable = false, .is_signer = false },
            .{ .pubkey = self.owner.key(), .is_writable = false, .is_signer = true },
        };

        // Instruction data: [discriminator(1)][amount(8)]
        var instruction_data: [9]u8 = undefined;
        instruction_data[0] = 4; // Discriminator
        std.mem.writeInt(u64, instruction_data[1..9], self.amount, .little);

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = &instruction_data,
        };

        // Invoke
        const accounts = [_]types.AccountInfo{ self.source, self.delegate, self.owner };
        try cpi.invokeSigned(&instruction, &accounts, signers_seeds);
    }
};

/// Approve a delegate with decimals check
///
/// Like Approve, but includes the mint and requires decimals to match.
/// This prevents errors from using the wrong decimal precision.
///
/// Accounts:
///   0. `[writable]` Token account to approve delegate for
///   1. `[]` Mint account
///   2. `[]` Delegate account
///   3. `[signer]` Owner of the token account
pub const ApproveChecked = struct {
    /// Token account (source)
    source: types.AccountInfo,
    /// Mint account
    mint: types.AccountInfo,
    /// Delegate account
    delegate: types.AccountInfo,
    /// Owner of the source account
    owner: types.AccountInfo,
    /// Amount the delegate is approved to transfer
    amount: u64,
    /// Expected decimals of the mint
    decimals: u8,

    /// Invoke the ApproveChecked instruction
    pub fn invoke(self: *const ApproveChecked) errors.ProgramError!void {
        return self.invokeSigned(&.{});
    }

    /// Invoke the ApproveChecked instruction with PDA signing
    pub fn invokeSigned(self: *const ApproveChecked, signers_seeds: []const []const u8) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            .{ .pubkey = self.source.key(), .is_writable = true, .is_signer = false },
            .{ .pubkey = self.mint.key(), .is_writable = false, .is_signer = false },
            .{ .pubkey = self.delegate.key(), .is_writable = false, .is_signer = false },
            .{ .pubkey = self.owner.key(), .is_writable = false, .is_signer = true },
        };

        // Instruction data: [discriminator(1)][amount(8)][decimals(1)]
        var instruction_data: [10]u8 = undefined;
        instruction_data[0] = 13; // Discriminator
        std.mem.writeInt(u64, instruction_data[1..9], self.amount, .little);
        instruction_data[9] = self.decimals;

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = &instruction_data,
        };

        // Invoke
        const accounts = [_]types.AccountInfo{ self.source, self.mint, self.delegate, self.owner };
        try cpi.invokeSigned(&instruction, &accounts, signers_seeds);
    }
};
