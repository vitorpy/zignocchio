//! MintTo instruction builders
//!
//! Mints new tokens to an account.

const std = @import("std");
const types = @import("../../types.zig");
const errors = @import("../../errors.zig");
const cpi = @import("../../cpi.zig");
const token_mod = @import("../mod.zig");

/// Mint new tokens to an account
///
/// Accounts:
///   0. `[writable]` Mint account
///   1. `[writable]` Destination token account
///   2. `[signer]` Mint authority
pub const MintTo = struct {
    /// Mint account
    mint: types.AccountInfo,
    /// Destination token account
    account: types.AccountInfo,
    /// Mint authority
    mint_authority: types.AccountInfo,
    /// Amount of tokens to mint
    amount: u64,

    /// Invoke the MintTo instruction
    pub fn invoke(self: *const MintTo) errors.ProgramError!void {
        return self.invokeSigned(&.{});
    }

    /// Invoke the MintTo instruction with PDA signing
    pub fn invokeSigned(self: *const MintTo, signers_seeds: []const []const []const u8) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            cpi.AccountMeta.writable(self.mint.key()),
            cpi.AccountMeta.writable(self.account.key()),
            cpi.AccountMeta.signer(self.mint_authority.key()),
        };

        // Build instruction data: [discriminator:1][amount:8]
        var instruction_data: [9]u8 = undefined;
        instruction_data[0] = 7; // discriminator
        std.mem.writeInt(u64, instruction_data[1..9], self.amount, .little);

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = &instruction_data,
        };

        // Invoke
        const accounts = [_]types.AccountInfo{ self.mint, self.account, self.mint_authority };
        try cpi.invokeSigned(&instruction, &accounts, signers_seeds);
    }
};

/// Mint new tokens to an account with decimals validation
///
/// Accounts:
///   0. `[writable]` Mint account
///   1. `[writable]` Destination token account
///   2. `[signer]` Mint authority
pub const MintToChecked = struct {
    /// Mint account
    mint: types.AccountInfo,
    /// Destination token account
    account: types.AccountInfo,
    /// Mint authority
    mint_authority: types.AccountInfo,
    /// Amount of tokens to mint
    amount: u64,
    /// Number of decimals (must match mint decimals)
    decimals: u8,

    /// Invoke the MintToChecked instruction
    pub fn invoke(self: *const MintToChecked) errors.ProgramError!void {
        return self.invokeSigned(&.{});
    }

    /// Invoke the MintToChecked instruction with PDA signing
    pub fn invokeSigned(self: *const MintToChecked, signers_seeds: []const []const []const u8) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            cpi.AccountMeta.writable(self.mint.key()),
            cpi.AccountMeta.writable(self.account.key()),
            cpi.AccountMeta.signer(self.mint_authority.key()),
        };

        // Build instruction data: [discriminator:1][amount:8][decimals:1]
        var instruction_data: [10]u8 = undefined;
        instruction_data[0] = 14; // discriminator
        std.mem.writeInt(u64, instruction_data[1..9], self.amount, .little);
        instruction_data[9] = self.decimals;

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = &instruction_data,
        };

        // Invoke
        const accounts = [_]types.AccountInfo{ self.mint, self.account, self.mint_authority };
        try cpi.invokeSigned(&instruction, &accounts, signers_seeds);
    }
};
