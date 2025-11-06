//! Initialize Vault Instruction
//!
//! Creates and initializes the vault token account PDA.
//! This must be done via CPI since PDAs cannot sign from the client.

const std = @import("std");
const sdk = @import("sdk");

/// Discriminator for initialize instruction
pub const DISCRIMINATOR: u8 = 2;

/// Validated accounts for initialize instruction
pub const InitializeAccounts = struct {
    vault_token_account: sdk.AccountInfo,
    mint: sdk.AccountInfo,
    owner: sdk.AccountInfo,
    system_program: sdk.AccountInfo,
    token_program: sdk.AccountInfo,
    rent_sysvar: sdk.AccountInfo,
    bump: u8,
};

/// Validate and parse initialize accounts
pub fn validateAccounts(
    accounts: []sdk.AccountInfo,
    program_id: *const sdk.Pubkey,
) sdk.ProgramError!InitializeAccounts {
    // Expect: vault_token_account, mint, owner, system_program, token_program, rent_sysvar
    if (accounts.len < 6) {
        sdk.logMsg("Error: Not enough accounts for initialize");
        return error.NotEnoughAccountKeys;
    }

    const vault_token_account = accounts[0];
    const mint = accounts[1];
    const owner = accounts[2];
    const system_program = accounts[3];
    const token_program = accounts[4];
    const rent_sysvar = accounts[5];

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

    // Validate system program ID
    const SYSTEM_PROGRAM_ID: sdk.Pubkey = .{
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
    };
    if (!sdk.pubkeyEq(system_program.key(), &SYSTEM_PROGRAM_ID)) {
        sdk.logMsg("Error: Invalid system program");
        return error.IncorrectProgramId;
    }

    // Derive and verify vault PDA
    const seed_owner = owner.key().*;
    const seeds = &[_][]const u8{ "vault", &seed_owner };
    var vault_key: sdk.Pubkey = undefined;
    var bump: u8 = undefined;
    try sdk.findProgramAddress(seeds, program_id, &vault_key, &bump);

    if (!sdk.pubkeyEq(vault_token_account.key(), &vault_key)) {
        sdk.logMsg("Error: Invalid vault token account PDA");
        return error.IncorrectProgramId;
    }

    return InitializeAccounts{
        .vault_token_account = vault_token_account,
        .mint = mint,
        .owner = owner,
        .system_program = system_program,
        .token_program = token_program,
        .rent_sysvar = rent_sysvar,
        .bump = bump,
    };
}

/// Process initialize instruction
pub fn process(
    program_id: *const sdk.Pubkey,
    accounts: []sdk.AccountInfo,
) sdk.ProgramResult {
    sdk.logMsg("Initialize: Starting");

    // Validate accounts
    const validated = try validateAccounts(accounts, program_id);

    sdk.logMsg("Initialize: Validated accounts");

    // Create account via System Program CPI
    const token_account_size: u64 = 165; // TokenAccount::LEN
    // Use a reasonable amount for rent exemption (approximately 0.002 SOL for 165 bytes)
    const lamports: u64 = 2_039_280;

    sdk.logMsg("Initialize: Creating account via CPI");
    sdk.logU64(lamports);
    sdk.logU64(token_account_size);

    // Build CreateAccount instruction
    const seed_owner = validated.owner.key().*;
    const bump_array = [_]u8{validated.bump};
    const signer_seeds = &[_][]const u8{
        "vault",
        seed_owner[0..],
        bump_array[0..],
    };

    // System Program CreateAccount instruction data
    // Format: [instruction:u32=0][lamports:u64][space:u64][owner:pubkey]
    var create_account_data: [52]u8 = undefined;
    std.mem.writeInt(u32, create_account_data[0..4], 0, .little); // CreateAccount = 0
    std.mem.writeInt(u64, create_account_data[4..12], lamports, .little);
    std.mem.writeInt(u64, create_account_data[12..20], token_account_size, .little);
    @memcpy(create_account_data[20..52], &sdk.token.TOKEN_PROGRAM_ID);

    const create_account_metas = [_]sdk.AccountMeta{
        .{ .pubkey = validated.owner.key(), .is_writable = true, .is_signer = true },
        .{ .pubkey = validated.vault_token_account.key(), .is_writable = true, .is_signer = true },
    };

    const SYSTEM_PROGRAM_ID: sdk.Pubkey = .{
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
    };

    const create_account_ix = sdk.Instruction{
        .program_id = &SYSTEM_PROGRAM_ID,
        .accounts = &create_account_metas,
        .data = &create_account_data,
    };

    const create_accounts = [_]sdk.AccountInfo{ validated.owner, validated.vault_token_account };
    try sdk.invokeSigned(&create_account_ix, &create_accounts, signer_seeds);

    sdk.logMsg("Initialize: Account created");

    // Initialize token account via Token Program CPI
    var init_account_data: [33]u8 = undefined;
    init_account_data[0] = 18; // InitializeAccount3
    @memcpy(init_account_data[1..33], validated.vault_token_account.key());

    const init_account_metas = [_]sdk.AccountMeta{
        .{ .pubkey = validated.vault_token_account.key(), .is_writable = true, .is_signer = false },
        .{ .pubkey = validated.mint.key(), .is_writable = false, .is_signer = false },
    };

    const init_account_ix = sdk.Instruction{
        .program_id = &sdk.token.TOKEN_PROGRAM_ID,
        .accounts = &init_account_metas,
        .data = &init_account_data,
    };

    const init_accounts = [_]sdk.AccountInfo{ validated.vault_token_account, validated.mint };
    try sdk.invoke(&init_account_ix, &init_accounts);

    sdk.logMsg("Initialize: Token account initialized");
}
