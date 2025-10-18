# Zignocchio Examples

Example programs demonstrating the Zignocchio SDK.

## Programs

### hello.zig
The simplest possible Solana program. Logs "Hello from Zignocchio!" and returns success.

**Features demonstrated:**
- Basic entrypoint setup
- Using the SDK logging functions
- Minimal program structure

### counter.zig
A counter program that stores and increments a u64 value.

**Features demonstrated:**
- Account validation (writable, ownership, size)
- Safe mutable data borrowing with RAII guards
- Reading and writing account data
- Instruction data parsing
- Error handling
- Compute unit logging

**Operations:**
- `0` - Increment counter
- `1` - Decrement counter
- `2` - Reset counter to 0
- No data - Default increment

## Building

To build these examples, you'll need to update `build.zig` to compile them instead of the current entrypoint.

### Example build.zig modification

```zig
// Change this line:
"-Mroot=src/entrypoint.zig",

// To one of:
"-Mroot=examples/hello.zig",
"-Mroot=examples/counter.zig",
```

Then run:
```bash
zig build
```

## Testing

After building, you can test the programs using the existing test infrastructure:

```bash
npm test
```

Note: You'll need to update the test expectations to match the example program's behavior.

## Learning Path

1. **hello.zig** - Start here to understand the basic structure
2. **counter.zig** - Learn about account management and data manipulation

## Key Concepts

### Zero-Copy Design
All account data is accessed directly from the input buffer - no allocations or copies.

### RAII Borrow Guards
The SDK uses RAII-style guards that automatically release borrows when they go out of scope:

```zig
{
    var data = try account.tryBorrowMutData();
    defer data.release();

    // Use data.value here
    // Borrow is automatically released at end of scope
}
```

### Type Safety
The SDK provides strong typing for all Solana primitives:
- `Pubkey` - Fixed 32-byte array
- `AccountInfo` - Safe wrapper around account data
- `ProgramError` - Enumerated error types

### Efficient Compute Usage
- Zero-copy deserialization
- Inline string data (no .rodata)
- Optimized pubkey comparison (8 bytes at a time)
- Minimal overhead borrowing system
