//! Deposit Instruction
//!
//! Handles token deposits into the vault.
//! Transfers tokens from user's token account to vault's token account.

const std = @import("std");
const sdk = @import("sdk");

/// Discriminator for deposit instruction
pub const DISCRIMINATOR: u8 = 0;

/// Validated accounts for deposit instruction
pub const DepositAccounts = struct {
    user_token_account: sdk.AccountInfo,
    vault_token_account: sdk.AccountInfo,
    owner: sdk.AccountInfo,
    token_program: sdk.AccountInfo,
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
    // Expect: user_token_account, vault_token_account, owner, token_program
    if (accounts.len < 4) {
        sdk.logMsg("Error: Not enough accounts for deposit");
        return error.NotEnoughAccountKeys;
    }

    const user_token_account = accounts[0];
    const vault_token_account = accounts[1];
    const owner = accounts[2];
    const token_program = accounts[3];

    // Validate owner must sign the transaction
    if (!owner.isSigner()) {
        sdk.logMsg("Error: Owner must be signer");
        return error.MissingRequiredSignature;
    }

    // Validate token program ID
    if (!sdk.pubkeyEq(token_program.key(), &sdk.token.TOKEN_PROGRAM_ID)) {
        sdk.logMsg("Error: Invalid token program");
        return error.IncorrectProgramId;
    }

    // Validate vault token account is owned by Token Program
    if (!sdk.pubkeyEq(vault_token_account.owner(), &sdk.token.TOKEN_PROGRAM_ID)) {
        sdk.logMsg("Error: Vault token account must be owned by Token Program");
        return error.IncorrectProgramId;
    }

    // Verify vault token account is the correct PDA for this owner
    const seed_owner = owner.key().*;
    const seeds = &[_][]const u8{ "vault", &seed_owner };
    var vault_key: sdk.Pubkey = undefined;
    var bump: u8 = undefined;
    try sdk.findProgramAddress(seeds, program_id, &vault_key, &bump);

    if (!sdk.pubkeyEq(vault_token_account.key(), &vault_key)) {
        sdk.logMsg("Error: Invalid vault token account PDA");
        return error.IncorrectProgramId;
    }

    return DepositAccounts{
        .user_token_account = user_token_account,
        .vault_token_account = vault_token_account,
        .owner = owner,
        .token_program = token_program,
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

    // Create Transfer instruction using SDK
    const transfer_ix = sdk.token.instructions.Transfer{
        .from = validated.user_token_account,
        .to = validated.vault_token_account,
        .authority = validated.owner,
        .amount = data.amount,
    };

    // Execute transfer
    try transfer_ix.invoke();

    sdk.logMsg("Deposit: Transfer completed successfully");
}
