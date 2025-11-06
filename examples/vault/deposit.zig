//! Deposit Instruction
//!
//! Handles user deposits into the vault.
//! Validates accounts and instruction data, then performs the lamport transfer.

const std = @import("std");
const sdk = @import("sdk");

/// System Program ID for CPI calls
pub const SYSTEM_PROGRAM_ID: sdk.Pubkey = .{
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
};

/// Discriminator for deposit instruction
pub const DISCRIMINATOR: u8 = 0;

/// Validated accounts for deposit instruction
pub const DepositAccounts = struct {
    owner: sdk.AccountInfo,
    vault: sdk.AccountInfo,
    system_program: sdk.AccountInfo,
};

/// Instruction data containing deposit amount
pub const DepositData = struct {
    amount: u64,
};

/// Validate and parse deposit accounts
pub fn validateAccounts(
    accounts: []sdk.AccountInfo,
    program_id: *const sdk.Pubkey,
) sdk.ProgramError!DepositAccounts {
    // Expect: owner, vault, system_program
    if (accounts.len < 3) {
        sdk.logMsg("Error: Not enough accounts for deposit");
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
    if (!sdk.pubkeyEq(vault.owner(), &SYSTEM_PROGRAM_ID)) {
        sdk.logMsg("Error: Vault must be owned by System Program");
        return error.IncorrectProgramId;
    }

    // Validate vault is empty (no double deposits)
    if (vault.lamports() != 0) {
        sdk.logMsg("Error: Vault must be empty");
        return error.InvalidAccountData;
    }

    // Verify vault is the correct PDA for this owner
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
    if (!sdk.pubkeyEq(system_program.key(), &SYSTEM_PROGRAM_ID)) {
        sdk.logMsg("Error: Invalid system program");
        return error.IncorrectProgramId;
    }

    return DepositAccounts{
        .owner = owner,
        .vault = vault,
        .system_program = system_program,
    };
}

/// Parse deposit instruction data
pub fn parseData(data: []const u8) sdk.ProgramError!DepositData {
    // Expect 8 bytes for u64 amount
    if (data.len != 8) {
        sdk.logMsg("Error: Invalid deposit data length");
        return error.InvalidInstructionData;
    }

    // Parse amount as little-endian u64
    const amount = std.mem.readInt(u64, data[0..8], .little);

    // Validate amount is greater than 0
    if (amount == 0) {
        sdk.logMsg("Error: Deposit amount must be greater than 0");
        return error.InvalidInstructionData;
    }

    return DepositData{ .amount = amount };
}

/// Process deposit instruction
pub fn process(
    program_id: *const sdk.Pubkey,
    accounts: []sdk.AccountInfo,
    instruction_data: []const u8,
) sdk.ProgramResult {
    sdk.logMsg("Deposit: Starting");

    // Validate accounts
    const validated = try validateAccounts(accounts, program_id);

    // Parse instruction data
    const data = try parseData(instruction_data);

    sdk.logMsg("Deposit: Validated accounts and data");
    sdk.logMsg("Deposit amount:");
    sdk.logU64(data.amount);

    // Create transfer instruction to System Program
    // Transfer from owner to vault
    const transfer_ix_data = createTransferInstruction(data.amount);

    const account_metas = [_]sdk.AccountMeta{
        .{ .pubkey = validated.owner.key(), .is_signer = true, .is_writable = true },
        .{ .pubkey = validated.vault.key(), .is_signer = false, .is_writable = true },
    };

    const instruction = sdk.Instruction{
        .program_id = &SYSTEM_PROGRAM_ID,
        .accounts = &account_metas,
        .data = &transfer_ix_data,
    };

    // Execute CPI to transfer lamports
    try sdk.invoke(&instruction, &[_]sdk.AccountInfo{ validated.owner, validated.vault });

    sdk.logMsg("Deposit: Transfer completed successfully");
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
