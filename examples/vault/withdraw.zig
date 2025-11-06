//! Withdraw Instruction
//!
//! Handles user withdrawals from the vault.
//! Validates accounts, ensures only the owner can withdraw, and performs the lamport transfer.

const std = @import("std");
const sdk = @import("sdk");
const deposit = @import("deposit.zig");

/// Discriminator for withdraw instruction
pub const DISCRIMINATOR: u8 = 1;

/// Validated accounts for withdraw instruction
pub const WithdrawAccounts = struct {
    owner: sdk.AccountInfo,
    vault: sdk.AccountInfo,
    system_program: sdk.AccountInfo,
    bump: u8,
};

/// Validate and parse withdraw accounts
pub fn validateAccounts(
    accounts: []sdk.AccountInfo,
    program_id: *const sdk.Pubkey,
) sdk.ProgramError!WithdrawAccounts {
    // Expect: owner, vault, system_program
    if (accounts.len < 3) {
        sdk.logMsg("Error: Not enough accounts for withdraw");
        return error.NotEnoughAccountKeys;
    }

    const owner = accounts[0];
    const vault = accounts[1];
    const system_program = accounts[2];

    // Validate owner must sign the transaction
    if (!owner.isSigner()) {
        sdk.logMsg("Error: Owner must be signer");
        return error.MissingRequiredSignature;
    }

    // Validate vault is owned by System Program
    if (!sdk.pubkeyEq(vault.owner(), &deposit.SYSTEM_PROGRAM_ID)) {
        sdk.logMsg("Error: Vault must be owned by System Program");
        return error.IncorrectProgramId;
    }

    // Verify vault is the correct PDA for this owner and get bump seed
    const seed_owner = owner.key().*;
    const seeds = &[_][]const u8{ "vault", &seed_owner };
    var vault_key: sdk.Pubkey = undefined;
    var bump: u8 = undefined;
    try sdk.findProgramAddress(seeds, program_id, &vault_key, &bump);

    if (!sdk.pubkeyEq(vault.key(), &vault_key)) {
        sdk.logMsg("Error: Invalid vault PDA");
        return error.IncorrectProgramId;
    }

    // Verify system program ID
    if (!sdk.pubkeyEq(system_program.key(), &deposit.SYSTEM_PROGRAM_ID)) {
        sdk.logMsg("Error: Invalid system program");
        return error.IncorrectProgramId;
    }

    return WithdrawAccounts{
        .owner = owner,
        .vault = vault,
        .system_program = system_program,
        .bump = bump,
    };
}

/// Process withdraw instruction
pub fn process(
    program_id: *const sdk.Pubkey,
    accounts: []sdk.AccountInfo,
) sdk.ProgramResult {
    sdk.logMsg("Withdraw: Starting");

    // Validate accounts
    const validated = try validateAccounts(accounts, program_id);

    // Get the amount to withdraw (all lamports in vault)
    const amount = validated.vault.lamports();

    sdk.logMsg("Withdraw: Validated accounts");
    sdk.logMsg("Withdraw amount:");
    sdk.logU64(amount);

    // Validate vault has lamports to withdraw
    if (amount == 0) {
        sdk.logMsg("Error: Vault is empty");
        return error.InsufficientFunds;
    }

    // Create transfer instruction to System Program
    // Transfer from vault to owner
    const transfer_ix_data = createTransferInstruction(amount);

    const account_metas = [_]sdk.AccountMeta{
        .{ .pubkey = validated.vault.key(), .is_signer = true, .is_writable = true },
        .{ .pubkey = validated.owner.key(), .is_signer = false, .is_writable = true },
    };

    const instruction = sdk.Instruction{
        .program_id = &deposit.SYSTEM_PROGRAM_ID,
        .accounts = &account_metas,
        .data = &transfer_ix_data,
    };

    // Create signer seeds for PDA signing
    const seed_owner = validated.owner.key().*;
    const bump_array = [_]u8{validated.bump};
    const signer_seeds = &[_][]const u8{
        "vault",
        seed_owner[0..],   // Explicit slice of pubkey bytes
        bump_array[0..],   // Explicit slice of bump byte
    };

    // Execute CPI with PDA signature
    try sdk.invokeSigned(&instruction, &[_]sdk.AccountInfo{ validated.vault, validated.owner }, signer_seeds);

    sdk.logMsg("Withdraw: Transfer completed successfully");
}

/// Create System Program Transfer instruction data
/// Format: [instruction_type: u32 = 2, amount: u64]
fn createTransferInstruction(amount: u64) [12]u8 {
    var data: [12]u8 = undefined;
    // System Program Transfer instruction type = 2
    std.mem.writeInt(u32, data[0..4], 2, .little);
    // Amount in lamports
    std.mem.writeInt(u64, data[4..12], amount, .little);
    return data;
}
