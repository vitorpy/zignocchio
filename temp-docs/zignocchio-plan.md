# Zignocchio SDK - Implementation Plan

## Overview
Building a zero-dependency Zig SDK for Solana programs, inspired by Pinocchio's architecture.

## Core Philosophy
- **Zero dependencies** - No external crates/packages
- **Zero-copy** - Direct memory access to input buffer
- **Minimal compute units** - Optimized for on-chain efficiency
- **Type-safe** - Leverage Zig's compile-time safety

## Architecture

### Directory Structure
```
./sdk/
├── zignocchio.zig          # Main SDK module
├── types.zig              # Core types (Pubkey, AccountInfo, Account)
├── entrypoint.zig         # Input deserialization & program entry
├── syscalls.zig           # Auto-generated syscalls (reuse our tools!)
├── allocator.zig          # BumpAllocator for heap management
├── pda.zig                # Program Derived Addresses
├── cpi.zig                # Cross-Program Invocation
├── log.zig                # Logging utilities
└── errors.zig             # Error types
```

## Key Features

### 1. Core Types (types.zig)

**Pubkey**
- Simple type alias: `pub const Pubkey = [32]u8`

**Account** - repr(C) packed struct matching Solana's memory layout:
```zig
pub const Account = extern struct {
    borrow_state: u8,      // Bit-packed borrow tracking
    is_signer: u8,
    is_writable: u8,
    executable: u8,
    resize_delta: i32,
    key: Pubkey,
    owner: Pubkey,
    lamports: u64,
    data_len: u64,
    // data follows immediately in memory
};
```

**AccountInfo** - thin wrapper:
```zig
pub const AccountInfo = struct {
    raw: *Account,
};
```

### 2. Borrow Tracking

Single `u8` bit-packed state (like Pinocchio's innovation):
- Bits 7-4: lamport borrows (1 mut flag + 3 bits for immutable count 0-7)
- Bits 3-0: data borrows (1 mut flag + 3 bits for immutable count 0-7)

Initial state: `0b_1111_1111` (NON_DUP_MARKER)

Borrow methods:
- `tryBorrowData()` → `Result<Ref<[]u8>, ProgramError>`
- `tryBorrowMutData()` → `Result<RefMut<[]u8>, ProgramError>`
- `tryBorrowLamports()` → `Result<Ref<u64>, ProgramError>`
- `tryBorrowMutLamports()` → `Result<RefMut<u64>, ProgramError>`

RAII-style guards that auto-release on scope exit.

### 3. Entrypoint (entrypoint.zig)

**deserialize() function**:
- Parse raw input buffer into:
  - `program_id: *const Pubkey`
  - `accounts: []AccountInfo`
  - `instruction_data: []const u8`
- Zero allocations, zero copies - all references into original buffer
- Handle duplicate account detection (via `NON_DUP_MARKER = 0xFF`)

**Input buffer layout**:
```
[8 bytes: num_accounts]
[Account 1 data]
  - 1 byte: duplicate marker (0xFF = not dup, else = index)
  - 7 bytes: padding
  - if not duplicate:
    - Account struct (88 bytes)
    - account data (variable)
    - padding to 8-byte alignment
[Account 2 data]
...
[8 bytes: instruction_data_len]
[instruction_data bytes]
[32 bytes: program_id]
```

### 4. Syscalls (syscalls.zig)

**Reuse existing generator!** We already have:
- `tools/murmur3.zig` - Hash function
- `tools/syscall_defs.zig` - Syscall definitions
- `tools/gen_syscalls.zig` - Generator

Just adapt output format for Zig SDK compatibility.

Generated format:
```zig
/// sol_log_
/// Hash: 0x207559bd
pub const sol_log_ = @as(*align(1) const fn([*]const u8, u64) void,
                         @ptrFromInt(0x207559bd));

// Convenience wrappers:
pub fn log(message: []const u8) void {
    sol_log_(message.ptr, message.len);
}
```

### 5. BumpAllocator (allocator.zig)

```zig
pub const HEAP_START_ADDRESS: usize = 0x300000000;
pub const HEAP_LENGTH: usize = 32 * 1024;

pub const BumpAllocator = struct {
    start: usize,
    len: usize,

    pub fn init() BumpAllocator {
        return .{
            .start = HEAP_START_ADDRESS,
            .len = HEAP_LENGTH,
        };
    }

    pub fn alloc(self: *BumpAllocator, size: usize, alignment: usize) ?[*]u8 {
        // Bump allocation logic
    }

    pub fn free(self: *BumpAllocator, ptr: [*]u8) void {
        // Bump allocator doesn't free!
    }
};
```

### 6. PDA Functions (pda.zig)

```zig
pub const MAX_SEEDS: usize = 16;
pub const MAX_SEED_LEN: usize = 32;
pub const PDA_MARKER: []const u8 = "ProgramDerivedAddress";

pub fn findProgramAddress(
    seeds: []const []const u8,
    program_id: *const Pubkey
) struct { Pubkey, u8 } {
    // Uses sol_try_find_program_address syscall
}

pub fn createProgramAddress(
    seeds: []const []const u8,
    program_id: *const Pubkey
) !Pubkey {
    // Uses sol_create_program_address syscall
}
```

### 7. CPI Support (cpi.zig)

```zig
pub const AccountMeta = extern struct {
    pubkey: *const Pubkey,
    is_signer: bool,
    is_writable: bool,
};

pub const Instruction = extern struct {
    program_id: *const Pubkey,
    accounts: []const AccountMeta,
    data: []const u8,
};

pub fn invoke(
    instruction: *const Instruction,
    accounts: []const AccountInfo
) !void {
    // Uses sol_invoke_signed_rust syscall
}

pub fn invokeSigned(
    instruction: *const Instruction,
    accounts: []const AccountInfo,
    seeds: []const []const u8
) !void {
    // Uses sol_invoke_signed_rust syscall
}
```

### 8. Error Types (errors.zig)

```zig
pub const ProgramError = error{
    AccountBorrowFailed,
    InvalidAccountData,
    InvalidArgument,
    InvalidInstructionData,
    MissingRequiredSignature,
    // ... more errors
};

pub const SUCCESS: u64 = 0;
```

### 9. Logging (log.zig)

```zig
pub fn log(message: []const u8) void {
    syscalls.sol_log_(message.ptr, message.len);
}

pub fn logU64(value: u64) void {
    syscalls.sol_log_64_(value, 0, 0, 0, 0);
}

pub fn logPubkey(pubkey: *const Pubkey) void {
    syscalls.sol_log_pubkey(@ptrCast(pubkey));
}
```

## Comparison: Pinocchio vs Zignocchio

| Feature | Pinocchio (Rust) | Zignocchio (Zig) |
|---------|-----------------|------------------|
| Dependencies | 0 | 0 |
| Borrow tracking | Single u8 | Single u8 |
| Syscalls | Macro-generated | Auto-generated via tools/ |
| Memory layout | repr(C) | extern struct |
| Safety | Runtime (RefCell-like) | Compile-time + runtime |
| Allocator | Bump | Bump |
| Lines of code | ~3,450 | TBD |

## Example Usage

```zig
const sdk = @import("sdk/zignocchio.zig");

export fn entrypoint(input: [*]u8) u64 {
    var accounts_buffer: [10]sdk.AccountInfo = undefined;

    const program_id, const accounts, const instruction_data =
        sdk.deserialize(input, &accounts_buffer);

    sdk.log("Hello from Zig!");

    const signer = accounts[0];
    if (!signer.isSigner()) return @intFromError(sdk.ProgramError.MissingRequiredSignature);

    const data = signer.tryBorrowMutData() catch return @intFromError(sdk.ProgramError.AccountBorrowFailed);
    defer data.release();

    // Write to account data...
    data.value[0] = 42;

    return sdk.SUCCESS;
}
```

## Implementation Tasks

1. ✅ Create SDK directory structure
2. ✅ Implement core types (Pubkey, Account, AccountInfo)
3. ✅ Implement borrow tracking with RAII guards
4. ✅ Create entrypoint deserializer
5. ✅ Integrate syscall generator
6. ✅ Implement BumpAllocator
7. ✅ Add PDA functions
8. ✅ Create logging utilities
9. ✅ Implement CPI support
10. ✅ Create example program
11. ✅ Write tests and documentation

## Benefits Over Current Approach

1. **Type safety** - Strong typing for accounts, PDAs, etc.
2. **Ergonomics** - Helper functions, no manual pointer arithmetic
3. **Safety** - Borrow checking prevents double-borrows
4. **Reusability** - Share common logic across programs
5. **Documentation** - Self-documenting API surface
6. **Efficiency** - Zero-copy, minimal CU consumption

## Technical Notes

### Memory Layout
All structs that map to Solana's memory layout must use `extern struct` to match C ABI.

### Alignment
Solana uses 8-byte alignment for u128 on BPF. Use `BPF_ALIGN_OF_U128 = 8`.

### Constants
```zig
pub const MAX_TX_ACCOUNTS: usize = 254;  // u8::MAX - 1
pub const NON_DUP_MARKER: u8 = 0xFF;
pub const MAX_PERMITTED_DATA_INCREASE: usize = 10 * 1024;
```

### Borrow State Bits
```
Bit 7: Lamports mutable borrow flag (1 = available, 0 = borrowed)
Bits 6-4: Lamports immutable borrow count (0-7)
Bit 3: Data mutable borrow flag (1 = available, 0 = borrowed)
Bits 2-0: Data immutable borrow count (0-7)
```

## References

- Pinocchio SDK: https://github.com/anza-xyz/pinocchio
- Solana Account Layout: https://solana.com/docs/core/accounts
- BPF Loader: https://github.com/anza-xyz/agave/tree/master/programs/bpf_loader
