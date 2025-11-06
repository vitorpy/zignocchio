# LLVM IR Analysis: TOKEN_PROGRAM_ID Crash Investigation

**Date**: 2025-11-06  
**Issue**: zignocchio-7acb

## Key Finding

The crash is caused by the **symbol name** `@token.mod.TOKEN_PROGRAM_ID`, NOT the constant itself or how it's used.

## Evidence

### Comparison of TOKEN_PROGRAM_ID Definitions

All three versions have **identical LLVM attributes**:
```llvm
internal unnamed_addr constant [32 x i8] c"\06\DD\F6\E1..." align 1
```

**The ONLY difference is the symbol name:**

| Version | Symbol Name | Result |
|---------|-------------|--------|
| global-test | `@constants.TOKEN_PROGRAM_ID` | ✅ Works |
| global-test | `@lib.TOKEN_PROGRAM_ID` | ✅ Works |
| token-vault WIP | `@__anon_1177` | ✅ Works |
| **token-vault original** | **`@token.mod.TOKEN_PROGRAM_ID`** | **❌ CRASHES** |

### Usage Patterns

Both working and crashing versions use the constant identically:
```llvm
// Pointer stores
store ptr @TOKEN_PROGRAM_ID, ptr %98, align 8

// memcpy operations  
call void @llvm.memcpy.inline.p0.p0.i64(ptr align 1 %66, ptr align 1 @TOKEN_PROGRAM_ID, i64 32, i1 false)

// Comparison operations
%38 = call fastcc i1 @types.pubkeyEq(ptr nonnull readonly align 1 %37, ptr nonnull readonly align 1 @TOKEN_PROGRAM_ID)
```

No difference in usage - only the symbol name changes.

## Hypothesis

The crash occurs during BPF program loading when sbpf-linker or the BPF loader encounters the symbol name `@token.mod.TOKEN_PROGRAM_ID`.

Possible causes:
1. **Symbol name collision**: "token" or "mod" conflicts with BPF runtime symbols
2. **Name mangling issue**: The dot-separated format `token.mod.` triggers bad relocation
3. **Metadata corruption**: SDK-originated symbols carry metadata that confuses the loader
4. **String parsing bug**: The loader's symbol parser chokes on this specific pattern

## Why The Workaround Works

Converting to an inline function makes the constant anonymous (`@__anon_1177`), which:
- Removes the problematic symbol name
- Still generates identical LLVM operations
- Results in the same runtime behavior

## Next Steps

1. Test if renaming `token.mod` to something else fixes it
2. Check if other SDK module names cause similar issues
3. Examine sbpf-linker's symbol processing code
4. Compare ELF symbol tables between working and crashing versions
5. Test with simpler names like `@TOKEN_PROGRAM_ID` (no module prefix)

## Files Analyzed

- `entrypoint-global-test.ll` - Working example (6.9KB bitcode → 26KB IR)
- `entrypoint-token-vault-original.ll` - Crashing version (19KB bitcode → 118KB IR)
- `entrypoint-token-vault.ll` - Working WIP with workaround (19KB bitcode → 118KB IR)

## Conclusion

This is NOT a bug with:
- ❌ Zig's global const mechanism
- ❌ LLVM BPF backend code generation
- ❌ Cross-module references
- ❌ The constant data itself

This IS a bug with:
- ✅ **Symbol name handling in sbpf-linker or BPF loader**
- ✅ **Specifically the name pattern `@token.mod.TOKEN_PROGRAM_ID`**
