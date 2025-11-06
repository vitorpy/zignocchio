//! # Vault Program - Educational Example using Zignocchio SDK
//!
//! This program demonstrates:
//! - Program Derived Addresses (PDAs) for secure vault accounts
//! - Cross-Program Invocation (CPI) to System Program for transfers
//! - Single-byte discriminators for instruction routing (0 = Deposit, 1 = Withdraw)
//! - Manual account validation and security checks
//! - Signed CPI using PDAs
//!
//! ## Overview
//! A minimalist lamport vault that allows users to securely store and withdraw SOL.
//! Users can deposit lamports into a PDA-based vault and withdraw them later.
//!
//! ## Instructions
//!
//! ### Deposit (discriminator = 0)
//! - Validates vault is empty (prevents double deposits)
//! - Ensures deposit amount is greater than zero
//! - Transfers lamports from owner to vault using CPI
//! - Uses PDA derived from owner's public key
//!
//! ### Withdraw (discriminator = 1)
//! - Verifies vault contains lamports
//! - Uses PDA signing to authorize the transfer
//! - Transfers all lamports back to the owner
//! - Ensures only the original depositor can withdraw
//!
//! ## Security Features
//! - Signer validation: Owner must sign all transactions
//! - Account ownership checks: Vault must be owned by System Program
//! - PDA verification: Vault address must match expected PDA derivation
//! - Amount validation: Prevents zero-amount transactions
//! - State validation: Prevents double deposits and empty withdrawals

const sdk = @import("sdk");
const deposit = @import("deposit.zig");
const withdraw = @import("withdraw.zig");

// NOTE: Program ID is NOT hardcoded. It's passed as a parameter to the entrypoint
// and propagated through processInstruction -> deposit/withdraw validators.
// This allows the same program binary to work with any deployed program address.

/// Program entrypoint
export fn entrypoint(input: [*]u8) u64 {
    return @call(.always_inline, sdk.createEntrypointWithMaxAccounts(5, processInstruction), .{input});
}

/// Process instruction - routes to appropriate handler based on discriminator
fn processInstruction(
    program_id: *const sdk.Pubkey,
    accounts: []sdk.AccountInfo,
    instruction_data: []const u8,
) sdk.ProgramResult {
    sdk.logMsg("Vault program: Starting");

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
            sdk.logMsg("Vault: Routing to Deposit");
            // Skip discriminator byte, pass remaining data
            const data = if (instruction_data.len > 1) instruction_data[1..] else &[_]u8{};
            return deposit.process(program_id, accounts, data);
        },
        withdraw.DISCRIMINATOR => {
            sdk.logMsg("Vault: Routing to Withdraw");
            return withdraw.process(program_id, accounts);
        },
        else => {
            sdk.logMsg("Error: Unknown instruction discriminator");
            return error.InvalidInstructionData;
        },
    }
}
