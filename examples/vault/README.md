# Vault Example - Zignocchio

A minimalist lamport vault program demonstrating PDA-based vault operations and Cross-Program Invocation (CPI) to the Solana System Program.

## Overview

This example implements a simple vault that allows users to securely store and withdraw SOL using Program Derived Addresses (PDAs). It showcases:

- **PDA-based security** - Vault addresses derived from owner's public key
- **Cross-Program Invocation (CPI)** - Transferring lamports via System Program
- **Single-byte discriminators** - Efficient instruction routing (0 = Deposit, 1 = Withdraw)
- **Manual account validation** - Complete control over security checks
- **Signed CPI with PDAs** - Vault signs withdrawals using PDA seeds

## Project Structure

```
examples/vault/
├── lib.zig        # Main entrypoint with instruction routing
├── deposit.zig    # Deposit instruction handler
├── withdraw.zig   # Withdraw instruction handler
└── README.md      # This file
```

### Educational Design

The vault is split into separate files (unlike hello.zig and counter.zig) to demonstrate:
- **Modular instruction handlers** - Each instruction in its own file
- **Shared types and utilities** - Common code in deposit.zig (like SYSTEM_PROGRAM_ID)
- **Clear separation of concerns** - Routing vs validation vs execution

## Instructions

### Deposit (discriminator = 0)

Transfers lamports from the owner to their PDA vault.

**Accounts:**
1. Owner (signer, writable) - User depositing funds
2. Vault (writable) - PDA derived from `["vault", owner_pubkey]`
3. System Program - For CPI transfer

**Instruction data:**
- Byte 0: Discriminator (0)
- Bytes 1-8: Amount (u64, little-endian)

**Validations:**
- Owner must sign
- Vault must be owned by System Program
- Vault must be empty (prevents double deposits)
- Vault address must match expected PDA
- Amount must be greater than 0

### Withdraw (discriminator = 1)

Transfers all lamports from the vault back to the owner.

**Accounts:**
1. Owner (signer, writable) - User withdrawing funds
2. Vault (writable) - PDA derived from `["vault", owner_pubkey]`
3. System Program - For CPI transfer

**Instruction data:**
- Byte 0: Discriminator (1)

**Validations:**
- Owner must sign
- Vault must be owned by System Program
- Vault address must match expected PDA
- Vault must contain lamports

**Note:** Uses PDA signing - the vault itself signs the transfer back to owner.

## Key Concepts Demonstrated

### 1. Program Derived Addresses (PDAs)

```zig
// Find PDA for vault
const seed_owner = owner.key().*;
const seeds = &[_][]const u8{ "vault", &seed_owner };
var vault_key: sdk.Pubkey = undefined;
var bump: u8 = undefined;
try sdk.findProgramAddress(seeds, program_id, &vault_key, &bump);
```

### 2. Cross-Program Invocation (CPI)

```zig
// Create System Program transfer instruction
const account_metas = [_]sdk.AccountMeta{
    .{ .pubkey = from.key(), .is_signer = true, .is_writable = true },
    .{ .pubkey = to.key(), .is_signer = false, .is_writable = true },
};

const instruction = sdk.Instruction{
    .program_id = &SYSTEM_PROGRAM_ID,
    .accounts = &account_metas,
    .data = &transfer_ix_data,
};

try sdk.invoke(&instruction, &[_]sdk.AccountInfo{ from, to });
```

### 3. Signed CPI with PDAs

```zig
// Withdraw uses PDA signing - vault signs the transfer
const signer_seeds = &[_][]const u8{
    "vault",
    &seed_owner,
    &bump_array,
};

try sdk.invokeSigned(&instruction, &[_]sdk.AccountInfo{ vault, owner }, signer_seeds);
```

## Building

```bash
zig build -Dexample=vault
```

Output: `zig-out/lib/program_name.so` (approx 8.5 KB)

## Testing

```bash
npm test -- vault.test.ts
```

The test file demonstrates:
- Deposit flow with amount validation
- Withdraw flow with PDA signing
- Full deposit-withdraw cycle
- Security checks (wrong signer, invalid PDA)

## Security Features

- **Signer validation**: Owner must sign all transactions
- **PDA verification**: Vault address must match expected derivation
- **Account ownership checks**: Vault owned by System Program
- **Amount validation**: Prevents zero-amount deposits
- **State validation**: Prevents double deposits and empty withdrawals
- **Atomic operations**: Each instruction is self-contained

## Implementation Notes

### sBPF Constraints

**Important**: sBPF doesn't support aggregate returns. The SDK's `findProgramAddress` uses output parameters:

```zig
// ❌ Not supported by sBPF
pub fn findProgramAddress(...) !struct { Pubkey, u8 }

// ✅ Uses output parameters instead
pub fn findProgramAddress(..., out_address: *Pubkey, out_bump: *u8) !void
```

This constraint applies to all sBPF programs - functions cannot return structs.

### System Program Transfer Format

System Program transfers use instruction type 2 with this format:

```zig
[4 bytes: instruction_type = 2 (u32 LE)]
[8 bytes: amount (u64 LE)]
```

See `createTransferInstruction()` in deposit.zig and withdraw.zig.

## Learning Path

If you're new to Solana programming, study the examples in this order:

1. **hello.zig** - Basic program structure and logging
2. **counter.zig** - Account data access and mutation
3. **vault/** - PDAs, CPI, and complex instruction handling

## Credits

Based on the [Pinocchio Vault Challenge](https://learn.blueshift.gg/en/challenges/pinocchio-vault) from Blueshift, adapted to Zig and Zignocchio SDK.

Original Rust implementation: [stellarnodeN/Pinocchio-Vault](https://github.com/stellarnodeN/Pinocchio-Vault)
