# For sbpf-linker Maintainers

## Quick Summary

sbpf-linker crashes when processing LLVM bitcode from Zig SDK-based programs. Simple Zig programs work fine.

**Error:** `Option::unwrap()` panic in `sbpf_assembler::instruction::Instruction::from_bytes` at `instruction.rs:84:48`

## Reproduction

### Setup
```bash
git clone <this-repository-url>
cd ziglana-the-return
```

### Working Case ✅
```bash
git checkout c58fdb6
rm -f entrypoint.bc
zig build

# Result: Success!
# Output: zig-out/lib/program_name.so (1.2KB)
```

### Failing Case ❌
```bash
git checkout feature/zignocchio-sdk
rm -f entrypoint.bc temp_example.zig
zig build

# Result: Crash!
# thread 'main' panicked at instruction.rs:84:48:
# called `Option::unwrap()` on a `None` value
```

## Artifacts

We've prepared these files in `temp-docs/`:

1. **sbpf-linker-crash.md** - Full crash analysis with backtrace
2. **ir-comparison.md** - Side-by-side LLVM IR comparison
3. **entrypoint.bc** - The actual failing bitcode file (in repo root after failed build)
4. **entrypoint.ll** - Human-readable LLVM IR (834 lines)

## Key Difference

| Aspect | Working | Failing |
|--------|---------|---------|
| LLVM IR size | 21 lines | 834 lines |
| Functions | 1 | Multiple (10+) |
| LLVM intrinsics | None | `llvm.memset`, `llvm.memcpy` |
| Struct types | None | Multiple complex types |
| Calling conv | Standard | `fastcc`, `sret` |

## Hypothesis

The crash happens in `byteparser.rs:67`:
```rust
let instruction = Instruction::from_bytes(node);
```

This suggests sbpf-linker is treating LLVM bitcode as raw sBPF bytecode, attempting to parse IR instructions as machine code opcodes.

For simple programs, this might coincidentally work or be bypassed. For complex programs with intrinsics, it fails because there's no sBPF opcode for `llvm.memset`.

## Expected Behavior

sbpf-linker should:
1. Parse LLVM bitcode as IR (using LLVM APIs)
2. Run optimization/lowering passes
3. Generate sBPF machine code
4. Perform linking

Currently it seems to skip IR parsing for complex patterns.

## Questions for You

1. Does sbpf-linker use LLVM's bitcode reader APIs or parse raw bytes?
2. Are LLVM intrinsics supposed to be lowered before reaching sbpf-linker?
3. Should we be passing `.o` files with embedded `.llvmic` sections instead of `.bc`?
4. Is there a flag or mode we're missing for SDK-level code?

## Contact

- **Repository:** (this repo)
- **Branch with issue:** feature/zignocchio-sdk
- **Working baseline:** commit c58fdb6

## Thank You!

We really appreciate your work on sbpf-linker. It's enabling us to build Solana programs in Zig, and we're excited to contribute to making it even better!
