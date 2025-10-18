# Zignocchio Examples

Example programs demonstrating the Zignocchio SDK for building Solana programs in Zig.

## Quick Start

```bash
# Build the hello world example
zig build -Dexample=hello

# Run its test (requires solana-test-validator)
npx jest examples/hello.test.ts
```

Expected output: `✓ 2 tests passed` with "Hello from Zignocchio!" in the logs.

---

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

Build the **counter** example (default):
```bash
zig build
# or explicitly
zig build -Dexample=counter
```

Build the **hello** example:
```bash
zig build -Dexample=hello
```

The compiled program will be at: `zig-out/lib/program_name.so`

### Build Requirements

- **Zig compiler** - Tested with Zig 0.13+
- **sbpf-linker** - Custom linker for Solana BPF programs (in `../sbpf-linker`)
- **LLVM** - For generating BPF bytecode

### Build Process

The build system uses a two-stage compilation:

1. **Zig → LLVM Bitcode**: Compiles Zig source to `.bc` (LLVM bitcode)
   - Target: `bpfel-freestanding` (BPF little-endian, freestanding)
   - CPU: `v2` (BPF ISA v2 - compatible with Solana sBPF)
   - Optimization: `ReleaseSmall` (minimal size)

2. **sbpf-linker → ELF**: Links bitcode into Solana-compatible ELF
   - Handles relocations for `.rodata` sections
   - Exports the `entrypoint` function
   - Produces stripped, dynamically linked ELF

## Testing

Each example has its own test file that automatically builds the correct program:

- `hello.test.ts` - Tests for the hello world program
- `counter.test.ts` - Tests for the counter program

### Prerequisites

Install dependencies (if you haven't already):
```bash
npm install
```

Make sure `solana-test-validator` is installed and in your PATH:
```bash
solana-test-validator --version
```

### Running Tests

Run **all tests**:
```bash
npm test
```

Run a **specific test**:
```bash
# Hello world test only
npx jest examples/hello.test.ts

# Counter test only
npx jest examples/counter.test.ts
```

### What the tests do

Each test:
1. Automatically builds the correct program (`zig build -Dexample=hello` or `counter`)
2. Starts a fresh `solana-test-validator` instance
3. Deploys the program to the validator
4. Funds a test account
5. Executes transactions against the program
6. Verifies logs and behavior
7. Cleans up the validator

**hello.test.ts covers:**
- ✓ Program executes successfully
- ✓ Logs "Hello from Zignocchio!" message
- ✓ Returns success with no errors
- ✓ Uses minimal compute units (~107 CU)

**counter.test.ts covers:**
- ✓ Creates a counter account with proper size
- ✓ Increment operation (default and explicit instruction)
- ✓ Decrement operation
- ✓ Reset operation
- ✓ Proper logging of counter values
- ✓ Error handling for invalid operations
- ✓ Overflow/underflow protection

### Test Output Example

Successful test run:
```
PASS examples/hello.test.ts
  Hello World Program
    ✓ should execute and log "Hello from Zignocchio!" (361 ms)
    ✓ should succeed with no errors (8107 ms)

Test Suites: 1 passed, 1 total
Tests:       2 passed, 2 total
```

### Troubleshooting

**Validator timeout**: If tests hang, kill any existing validator:
```bash
pkill -f solana-test-validator
```

**Port in use**: The validator uses port 8899. Make sure it's not in use:
```bash
lsof -i :8899
```

**Build errors**: Make sure sbpf-linker is built:
```bash
cd ../sbpf-linker
cargo build
```

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
- Minimal .rodata footprint (strings handled efficiently)
- Optimized pubkey comparison (8 bytes at a time)
- Minimal overhead borrowing system

### BPF ISA Compatibility
- Uses BPF ISA v2 (compatible with Solana sBPF)
- No 32-bit jump instructions (which conflict with Solana PQR opcodes)
- Custom sbpf-linker handles LLVM's `.rodata.str1.1` sections
- Stripped, position-independent code for minimal size
