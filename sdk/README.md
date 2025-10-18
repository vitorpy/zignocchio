# Zignocchio SDK

A zero-dependency, zero-copy Zig SDK for building Solana programs.

## Overview

Zignocchio is inspired by [Pinocchio](https://github.com/anza-xyz/pinocchio) and brings the same philosophy to Zig:
- **Zero dependencies** - No external packages required
- **Zero-copy** - Direct memory access to the input buffer
- **Minimal compute units** - Optimized for on-chain efficiency
- **Type-safe** - Leverages Zig's compile-time safety

## Features

### Core Types
- `Pubkey` - 32-byte public key
- `Account` - Low-level account structure matching Solana's memory layout
- `AccountInfo` - Safe wrapper with borrow tracking
- `ProgramError` - Comprehensive error types

### Borrow Tracking
Single-byte bit-packed borrow state tracking:
- Supports up to 7 simultaneous immutable borrows per field
- 1 mutable borrow per field (data or lamports)
- RAII-style guards for automatic cleanup
- Prevents double-borrows across duplicate accounts

### Input Deserialization
- Zero-copy parsing of Solana's input buffer
- Handles duplicate account detection
- Type-safe access to program_id, accounts, and instruction data
- Configurable maximum account count

### Syscalls
- Auto-generated from Solana definitions using MurmurHash3
- Type-safe wrappers for all Solana syscalls
- Convenience functions for common operations

### Memory Management
- BumpAllocator for efficient heap allocation
- Configurable heap size (default 32KB)
- Compatible with Zig's `std.mem.Allocator` interface

### PDAs (Program Derived Addresses)
- `findProgramAddress()` - Find valid PDA with bump seed
- `createProgramAddress()` - Create PDA from known seeds
- `createWithSeed()` - Derive address using SHA256

### CPI (Cross-Program Invocation)
- `invoke()` - Call other programs
- `invokeSigned()` - Call other programs with PDA signatures
- `setReturnData()` / `getReturnData()` - Return data handling
- Automatic borrow validation before CPI

### Logging
- `logMsg()` - Log string messages
- `logU64()` / `log64()` - Log numeric values
- `logPubkey()` - Log public keys
- `logComputeUnits()` - Log remaining compute units

## Quick Start

### Basic Program

```zig
const sdk = @import("sdk/zignocchio.zig");

export fn entrypoint(input: [*]u8) u64 {
    return @call(.always_inline, sdk.createEntrypoint(processInstruction), .{input});
}

fn processInstruction(
    program_id: *const sdk.Pubkey,
    accounts: []sdk.AccountInfo,
    instruction_data: []const u8,
) sdk.ProgramResult {
    sdk.logMsg("Hello from Zignocchio!");
    return .{};
}
```

### Working with Accounts

```zig
fn processInstruction(
    program_id: *const sdk.Pubkey,
    accounts: []sdk.AccountInfo,
    instruction_data: []const u8,
) sdk.ProgramResult {
    const account = accounts[0];

    // Check account properties
    if (!account.isWritable()) return error.ImmutableAccount;
    if (!account.isOwnedBy(program_id)) return error.IncorrectProgramId;

    // Borrow data mutably (RAII guard)
    var data = try account.tryBorrowMutData();
    defer data.release();

    // Access data
    data.value[0] = 42;

    return .{};
}
```

### Program Derived Addresses

```zig
fn processInstruction(
    program_id: *const sdk.Pubkey,
    accounts: []sdk.AccountInfo,
    instruction_data: []const u8,
) sdk.ProgramResult {
    const seeds = &[_][]const u8{
        "counter",
        &accounts[0].key().*,
    };

    const pda, const bump = try sdk.findProgramAddress(seeds, program_id);

    sdk.logMsg("Found PDA:");
    sdk.logPubkey(&pda);
    sdk.logMsg("Bump seed:");
    sdk.logU64(bump);

    return .{};
}
```

### Cross-Program Invocation

```zig
fn processInstruction(
    program_id: *const sdk.Pubkey,
    accounts: []sdk.AccountInfo,
    instruction_data: []const u8,
) sdk.ProgramResult {
    const instruction = sdk.Instruction{
        .program_id = &target_program_id,
        .accounts = &[_]sdk.AccountMeta{
            .{ .pubkey = accounts[0].key(), .is_signer = false, .is_writable = true },
        },
        .data = &[_]u8{ 1, 2, 3 },
    };

    try sdk.invoke(&instruction, accounts);

    return .{};
}
```

## Architecture

### Module Structure

```
sdk/
├── zignocchio.zig    # Main module (re-exports everything)
├── types.zig         # Core types (Pubkey, Account, AccountInfo)
├── errors.zig        # Error types
├── syscalls.zig      # Auto-generated syscalls
├── entrypoint.zig    # Input deserialization
├── log.zig           # Logging utilities
├── allocator.zig     # BumpAllocator
├── pda.zig           # PDA functions
└── cpi.zig           # Cross-program invocation
```

### Memory Layout

#### Account Structure (88 bytes + data)
```
Offset  | Size | Field
--------|------|-------------
0       | 1    | borrow_state (bit-packed)
1       | 1    | is_signer
2       | 1    | is_writable
3       | 1    | executable
4       | 4    | resize_delta
8       | 32   | key (Pubkey)
40      | 32   | owner (Pubkey)
72      | 8    | lamports
80      | 8    | data_len
88      | var  | data (inline, follows immediately)
```

#### Borrow State Bits
```
Bit 7: Lamports mutable borrow (1 = available)
Bits 6-4: Lamports immutable borrow count (0-7)
Bit 3: Data mutable borrow (1 = available)
Bits 2-0: Data immutable borrow count (0-7)

Initial: 0b_1111_1111 (NON_DUP_MARKER)
```

## Design Principles

### Zero-Copy
All data structures are designed to directly reference the Solana input buffer without copies:
- `AccountInfo` holds a pointer to `Account` in the input buffer
- Deserialization creates references, not copies
- Account data accessed via pointer arithmetic

### Type Safety
Zig's type system ensures:
- No null pointer dereferences
- No buffer overflows
- Compile-time bounds checking where possible
- Strong typing for all Solana primitives

### Efficiency
- Bit-packed borrow state (1 byte vs 2 cells in standard SDK)
- Optimized pubkey comparison (8 bytes at a time)
- Inline syscall definitions
- Zero allocation deserialization

### Simplicity
- Clear, documented API
- RAII patterns for resource management
- Familiar abstractions (inspired by Rust's std)
- Minimal boilerplate

## Comparison with Pinocchio

| Feature | Pinocchio (Rust) | Zignocchio (Zig) |
|---------|-----------------|------------------|
| Dependencies | 0 | 0 |
| Borrow tracking | 1 byte | 1 byte |
| Syscalls | Macro-generated | Auto-generated |
| Memory layout | repr(C) | extern struct |
| Safety | Runtime | Compile-time + runtime |
| Allocator | Bump | Bump |
| Language | Rust | Zig |

## Building

See the main project README and `examples/README.md` for build instructions.

## Examples

See the `examples/` directory for complete working programs:
- `hello.zig` - Minimal example
- `counter.zig` - Full-featured example with account management

## Contributing

Contributions are welcome! Please ensure:
- Code follows Zig style conventions
- All public APIs are documented
- Examples demonstrate new features
- Tests pass (when available)

## License

MIT (same as the parent project)

## Acknowledgments

- Inspired by [Pinocchio](https://github.com/anza-xyz/pinocchio) by Anza
- Built on top of [sbpf-linker](https://github.com/blueshift-gg/sbpf-linker)
- Uses Zig's standard BPF target

## Related Resources

- [Solana Documentation](https://docs.solana.com/)
- [Pinocchio SDK](https://github.com/anza-xyz/pinocchio)
- [sbpf-linker](https://github.com/blueshift-gg/sbpf-linker)
- [Zig Language](https://ziglang.org/)
