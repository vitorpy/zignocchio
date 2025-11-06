//! InitializeAccount instruction builders
//!
//! These instructions initialize a new token account for a specific mint.
//! Three variants exist for different use cases.

const std = @import("std");
const types = @import("../../types.zig");
const errors = @import("../../errors.zig");
const cpi = @import("../../cpi.zig");
const token_mod = @import("../mod.zig");

/// Initialize a new token account (legacy version)
///
/// Accounts:
///   0. `[writable]` Token account to initialize
///   1. `[]` Mint account
///   2. `[]` Owner account
///   3. `[]` Rent sysvar
pub const InitializeAccount = struct {
    /// Token account to initialize
    account: types.AccountInfo,
    /// Mint account
    mint: types.AccountInfo,
    /// Owner account
    owner: types.AccountInfo,
    /// Rent sysvar
    rent_sysvar: types.AccountInfo,

    /// Invoke the InitializeAccount instruction
    pub fn invoke(self: *const InitializeAccount) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            .{ .pubkey = self.account.key(), .is_writable = true, .is_signer = false },
            .{ .pubkey = self.mint.key(), .is_writable = false, .is_signer = false },
            .{ .pubkey = self.owner.key(), .is_writable = false, .is_signer = false },
            .{ .pubkey = self.rent_sysvar.key(), .is_writable = false, .is_signer = false },
        };

        // Instruction data: just discriminator
        const instruction_data = [_]u8{1};

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = &instruction_data,
        };

        // Invoke
        const accounts = [_]types.AccountInfo{ self.account, self.mint, self.owner, self.rent_sysvar };
        try cpi.invoke(&instruction, &accounts);
    }
};

/// Initialize a new token account (modern version with owner in data)
///
/// Accounts:
///   0. `[writable]` Token account to initialize
///   1. `[]` Mint account
///   2. `[]` Rent sysvar
pub const InitializeAccount2 = struct {
    /// Token account to initialize
    account: types.AccountInfo,
    /// Mint account
    mint: types.AccountInfo,
    /// Rent sysvar
    rent_sysvar: types.AccountInfo,
    /// Owner pubkey (in instruction data)
    owner: *const types.Pubkey,

    /// Invoke the InitializeAccount2 instruction
    pub fn invoke(self: *const InitializeAccount2) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            .{ .pubkey = self.account.key(), .is_writable = true, .is_signer = false },
            .{ .pubkey = self.mint.key(), .is_writable = false, .is_signer = false },
            .{ .pubkey = self.rent_sysvar.key(), .is_writable = false, .is_signer = false },
        };

        // Build instruction data: [discriminator:1][owner:32]
        var instruction_data: [33]u8 = undefined;
        instruction_data[0] = 16;
        @memcpy(instruction_data[1..33], self.owner);

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = &instruction_data,
        };

        // Invoke
        const accounts = [_]types.AccountInfo{ self.account, self.mint, self.rent_sysvar };
        try cpi.invoke(&instruction, &accounts);
    }
};

/// Initialize a new token account (most modern version, no rent sysvar)
///
/// Accounts:
///   0. `[writable]` Token account to initialize
///   1. `[]` Mint account
pub const InitializeAccount3 = struct {
    /// Token account to initialize
    account: types.AccountInfo,
    /// Mint account
    mint: types.AccountInfo,
    /// Owner pubkey (in instruction data)
    owner: *const types.Pubkey,

    /// Invoke the InitializeAccount3 instruction
    pub fn invoke(self: *const InitializeAccount3) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            .{ .pubkey = self.account.key(), .is_writable = true, .is_signer = false },
            .{ .pubkey = self.mint.key(), .is_writable = false, .is_signer = false },
        };

        // Build instruction data: [discriminator:1][owner:32]
        var instruction_data: [33]u8 = undefined;
        instruction_data[0] = 18;
        @memcpy(instruction_data[1..33], self.owner);

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = &instruction_data,
        };

        // Invoke
        const accounts = [_]types.AccountInfo{ self.account, self.mint };
        try cpi.invoke(&instruction, &accounts);
    }
};
