//! # Token Vault Program - Educational Example using Zignocchio SDK
//!
//! This program demonstrates:
//! - Managing SPL Token deposits and withdrawals
//! - Token Program CPI for transfers
//! - PDA-based token account management
//! - Signed CPI for PDA token accounts
//!
//! ## Overview
//! A token vault that allows users to deposit SPL tokens into a vault token account
//! and withdraw them later. The vault uses a PDA-based token account to hold user deposits.
//!
//! ## Instructions
//!
//! ### Deposit (discriminator = 0)
//! - Transfers tokens from user's token account to vault token account
//! - Uses Token Program Transfer instruction via CPI
//! - Validates all token accounts
//!
//! ### Withdraw (discriminator = 1)
//! - Transfers tokens from vault token account back to user
//! - Uses PDA signing to authorize the transfer
//! - Transfers all tokens in the vault
//!
//! ## Security Features
//! - Signer validation: Owner must sign all transactions
//! - Token account validation: All accounts must be valid token accounts
//! - PDA verification: Vault account must match expected PDA
//! - Amount validation: Prevents zero-amount transactions

const sdk = @import("sdk");
const initialize = @import("initialize.zig");
const deposit = @import("deposit.zig");
const withdraw = @import("withdraw.zig");

/// Program entrypoint
export fn entrypoint(input: [*]u8) u64 {
    return @call(.always_inline, sdk.createEntrypointWithMaxAccounts(10, processInstruction), .{input});
}

/// Process instruction - routes to appropriate handler based on discriminator
fn processInstruction(
    program_id: *const sdk.Pubkey,
    accounts: []sdk.AccountInfo,
    instruction_data: []const u8,
) sdk.ProgramResult {
    sdk.logMsg("Token Vault program: Starting");

    // Instruction data must have at least 1 byte (discriminator)
    if (instruction_data.len == 0) {
        sdk.logMsg("Error: Empty instruction data");
        return error.InvalidInstructionData;
    }

    // Read discriminator (first byte)
    const discriminator = instruction_data[0];

    // Route to appropriate instruction handler
    switch (discriminator) {
        deposit.DISCRIMINATOR => {
            sdk.logMsg("Token Vault: Routing to Deposit");
            const data = if (instruction_data.len > 1) instruction_data[1..] else &[_]u8{};
            return deposit.process(program_id, accounts, data);
        },
        withdraw.DISCRIMINATOR => {
            sdk.logMsg("Token Vault: Routing to Withdraw");
            return withdraw.process(program_id, accounts);
        },
        initialize.DISCRIMINATOR => {
            sdk.logMsg("Token Vault: Routing to Initialize");
            return initialize.process(program_id, accounts);
        },
        else => {
            sdk.logMsg("Error: Unknown instruction discriminator");
            return error.InvalidInstructionData;
        },
    }
}
