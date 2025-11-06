//! Burn instruction builders
//!
//! Burns (destroys) tokens by removing them from an account.

const std = @import("std");
const types = @import("../../types.zig");
const errors = @import("../../errors.zig");
const cpi = @import("../../cpi.zig");
const token_mod = @import("../mod.zig");

/// Burn tokens from an account
///
/// Accounts:
///   0. `[writable]` Token account to burn from
///   1. `[writable]` Mint account
///   2. `[signer]` Authority (owner or delegate)
pub const Burn = struct {
    /// Token account to burn from
    account: types.AccountInfo,
    /// Mint account
    mint: types.AccountInfo,
    /// Authority (owner or delegate of token account)
    authority: types.AccountInfo,
    /// Amount of tokens to burn
    amount: u64,

    /// Invoke the Burn instruction
    pub inline fn invoke(self: *const Burn) errors.ProgramError!void {
        return self.invokeSigned(&.{});
    }

    /// Invoke the Burn instruction with PDA signing
    pub inline fn invokeSigned(self: *const Burn, signers_seeds: []const []const u8) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            .{ .pubkey = self.account.key(), .is_writable = true, .is_signer = false },
            .{ .pubkey = self.mint.key(), .is_writable = true, .is_signer = false },
            .{ .pubkey = self.authority.key(), .is_writable = false, .is_signer = true },
        };

        // Build instruction data: [discriminator:1][amount:8]
        var instruction_data: [9]u8 = undefined;
        instruction_data[0] = 8; // discriminator
        std.mem.writeInt(u64, instruction_data[1..9], self.amount, .little);

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = &instruction_data,
        };

        // Invoke
        const accounts = [_]types.AccountInfo{ self.account, self.mint, self.authority };
        try cpi.invokeSigned(&instruction, &accounts, signers_seeds);
    }
};

/// Burn tokens from an account with decimals validation
///
/// Accounts:
///   0. `[writable]` Token account to burn from
///   1. `[writable]` Mint account
///   2. `[signer]` Authority (owner or delegate)
pub const BurnChecked = struct {
    /// Token account to burn from
    account: types.AccountInfo,
    /// Mint account
    mint: types.AccountInfo,
    /// Authority (owner or delegate of token account)
    authority: types.AccountInfo,
    /// Amount of tokens to burn
    amount: u64,
    /// Number of decimals (must match mint decimals)
    decimals: u8,

    /// Invoke the BurnChecked instruction
    pub inline fn invoke(self: *const BurnChecked) errors.ProgramError!void {
        return self.invokeSigned(&.{});
    }

    /// Invoke the BurnChecked instruction with PDA signing
    pub inline fn invokeSigned(self: *const BurnChecked, signers_seeds: []const []const u8) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            .{ .pubkey = self.account.key(), .is_writable = true, .is_signer = false },
            .{ .pubkey = self.mint.key(), .is_writable = true, .is_signer = false },
            .{ .pubkey = self.authority.key(), .is_writable = false, .is_signer = true },
        };

        // Build instruction data: [discriminator:1][amount:8][decimals:1]
        var instruction_data: [10]u8 = undefined;
        instruction_data[0] = 15; // discriminator
        std.mem.writeInt(u64, instruction_data[1..9], self.amount, .little);
        instruction_data[9] = self.decimals;

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = &instruction_data,
        };

        // Invoke
        const accounts = [_]types.AccountInfo{ self.account, self.mint, self.authority };
        try cpi.invokeSigned(&instruction, &accounts, signers_seeds);
    }
};
