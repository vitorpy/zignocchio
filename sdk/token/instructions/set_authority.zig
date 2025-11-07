//! SetAuthority instruction builder
//!
//! Changes the authority of a mint or token account.

const std = @import("std");
const types = @import("../../types.zig");
const errors = @import("../../errors.zig");
const cpi = @import("../../cpi.zig");
const token_mod = @import("../mod.zig");

/// Authority type to set
pub const AuthorityType = enum(u8) {
    /// Authority to mint new tokens
    MintTokens = 0,
    /// Authority to freeze token accounts
    FreezeAccount = 1,
    /// Owner of a token account
    AccountOwner = 2,
    /// Authority to close a token account
    CloseAccount = 3,
};

/// Set or remove authority of a mint or token account
///
/// Changes the authority for mint operations, freezing, account ownership, or account closing.
/// If new_authority is null, the authority is removed (cannot be recovered).
///
/// Accounts:
///   0. `[writable]` Mint or token account
///   1. `[signer]` Current authority
pub const SetAuthority = struct {
    /// Mint or token account to modify
    owned: types.AccountInfo,
    /// Current authority
    current_authority: types.AccountInfo,
    /// Type of authority to update
    authority_type: AuthorityType,
    /// New authority (null to remove authority permanently)
    new_authority: ?*const types.Pubkey,

    /// Invoke the SetAuthority instruction
    pub fn invoke(self: *const SetAuthority) errors.ProgramError!void {
        return self.invokeSigned(&.{});
    }

    /// Invoke the SetAuthority instruction with PDA signing
    pub fn invokeSigned(self: *const SetAuthority, signers_seeds: []const []const u8) errors.ProgramError!void {
        // Build account metas
        const account_metas = [_]cpi.AccountMeta{
            .{ .pubkey = self.owned.key(), .is_writable = true, .is_signer = false },
            .{ .pubkey = self.current_authority.key(), .is_writable = false, .is_signer = true },
        };

        // Build instruction data: [discriminator(1)][authority_type(1)][option(1)][new_authority?(32)]
        var instruction_data: [35]u8 = undefined;
        instruction_data[0] = 6; // Discriminator
        instruction_data[1] = @intFromEnum(self.authority_type);

        if (self.new_authority) |new_auth| {
            instruction_data[2] = 1; // COption::Some
            @memcpy(instruction_data[3..35], new_auth);
        } else {
            instruction_data[2] = 0; // COption::None
            // Remaining bytes don't matter when COption is None
        }

        // Build instruction
        const instruction = cpi.Instruction{
            .program_id = &token_mod.TOKEN_PROGRAM_ID,
            .accounts = &account_metas,
            .data = if (self.new_authority != null) &instruction_data else instruction_data[0..3],
        };

        // Invoke
        const accounts = [_]types.AccountInfo{ self.owned, self.current_authority };
        try cpi.invokeSigned(&instruction, &accounts, signers_seeds);
    }
};
