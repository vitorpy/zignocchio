//! InitializeMint and InitializeMint2 instruction builders
//!
//! InitializeMint creates a new mint account with decimals and authorities.
//! InitializeMint2 is the modern version that doesn't require the rent sysvar.

const std = @import("std");
const types = @import("../../types.zig");
const errors = @import("../../errors.zig");
const cpi = @import("../../cpi.zig");
const token_mod = @import("../mod.zig");

/// Initialize a new mint (legacy version requiring rent sysvar)
///
/// Accounts:
///   0. `[writable]` Mint account
///   1. `[]` Rent sysvar
pub const InitializeMint = struct {
    /// Mint account
    mint: types.AccountInfo,
    /// Rent sysvar account
    rent_sysvar: types.AccountInfo,
    /// Number of decimals
    decimals: u8,
    /// Mint authority
    mint_authority: *const types.Pubkey,
    /// Optional freeze authority
    freeze_authority: ?*const types.Pubkey,

    /// Invoke the InitializeMint instruction
    pub fn invoke(self: *const InitializeMint) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            cpi.AccountMeta.writable(self.mint.key()),
            cpi.AccountMeta.readonly(self.rent_sysvar.key()),
        };

        // Build instruction data
        // Layout: [discriminator:1][decimals:1][mint_authority:32][freeze_flag:1][freeze_authority:32]
        var instruction_data: [67]u8 = undefined;
        var length: usize = instruction_data.len;

        // Discriminator = 0
        instruction_data[0] = 0;
        // Decimals
        instruction_data[1] = self.decimals;
        // Mint authority
        @memcpy(instruction_data[2..34], self.mint_authority);

        // Freeze authority (optional)
        if (self.freeze_authority) |freeze_auth| {
            instruction_data[34] = 1; // Some
            @memcpy(instruction_data[35..67], freeze_auth);
        } else {
            instruction_data[34] = 0; // None
            length = 35; // Truncate if no freeze authority
        }

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = instruction_data[0..length],
        };

        // Invoke
        const accounts = [_]types.AccountInfo{ self.mint, self.rent_sysvar };
        try cpi.invoke(&instruction, &accounts);
    }
};

/// Initialize a new mint (modern version, no rent sysvar required)
///
/// Accounts:
///   0. `[writable]` Mint account
pub const InitializeMint2 = struct {
    /// Mint account
    mint: types.AccountInfo,
    /// Number of decimals
    decimals: u8,
    /// Mint authority
    mint_authority: *const types.Pubkey,
    /// Optional freeze authority
    freeze_authority: ?*const types.Pubkey,

    /// Invoke the InitializeMint2 instruction
    pub fn invoke(self: *const InitializeMint2) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            cpi.AccountMeta.writable(self.mint.key()),
        };

        // Build instruction data
        // Layout: [discriminator:1][decimals:1][mint_authority:32][freeze_flag:1][freeze_authority:32]
        var instruction_data: [67]u8 = undefined;
        var length: usize = instruction_data.len;

        // Discriminator = 20
        instruction_data[0] = 20;
        // Decimals
        instruction_data[1] = self.decimals;
        // Mint authority
        @memcpy(instruction_data[2..34], self.mint_authority);

        // Freeze authority (optional)
        if (self.freeze_authority) |freeze_auth| {
            instruction_data[34] = 1; // Some
            @memcpy(instruction_data[35..67], freeze_auth);
        } else {
            instruction_data[34] = 0; // None
            length = 35; // Truncate if no freeze authority
        }

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = instruction_data[0..length],
        };

        // Invoke
        const accounts = [_]types.AccountInfo{self.mint};
        try cpi.invoke(&instruction, &accounts);
    }
};
