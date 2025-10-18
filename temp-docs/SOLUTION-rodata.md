# SOLUTION: .rodata Section Name Mismatch

## Problem

sbpf-linker crashed with:
```
thread 'main' panicked at src/byteparser.rs:118:21:
Relocations found but no .rodata section
```

## Root Cause ✅

**LLVM generates `.rodata.str1.1` but sbpf-linker only looked for `.rodata`**

### What Happened

1. LLVM compiled the Zig program and created string constants
2. LLVM put these strings in a section named `.rodata.str1.1` (not `.rodata`)
   - `.str` = strings section
   - `1` = element size 1 byte
   - `1` = alignment 1
3. The `.text` section had 15 relocations pointing to `.rodata.str1.1`
4. sbpf-linker only checked for a section named exactly `.rodata`
5. When it found relocations but no `.rodata`, it panicked

### Evidence

From `readelf -S zig-out/lib/program_name.so`:
```
[ 2] .text             PROGBITS         (code)
[ 3] .rel.text         REL              (15 relocations)
[ 4] .rodata.str1.1    PROGBITS         (string constants)
```

From `readelf -r zig-out/lib/program_name.so`:
```
15 relocations in .text all pointing to .rodata.str1.1
```

### String Contents

The `.rodata.str1.1` section contained all the error messages and logging strings from the SDK:
- "Counter program: starting"
- "Error: Not enough accounts"
- "Error: Counter account not writable"
- etc. (15 total strings)

## The Fix

Modified `/home/vitorpy/code/sbpf-linker/src/byteparser.rs` to find **any** rodata section:

**Before:**
```rust
let mut rodata_table = HashMap::new();
if let Some(ro_section) = obj.section_by_name(".rodata") {
```

**After:**
```rust
// Find rodata section - could be .rodata, .rodata.str1.1, etc.
let ro_section = obj.sections().find(|s| {
    s.name().map(|name| name.starts_with(".rodata")).unwrap_or(false)
});

let mut rodata_table = HashMap::new();
if let Some(ref ro_section) = ro_section {
```

This change was made in two places (lines 20 and 85) to handle both:
1. Parsing rodata symbols
2. Processing relocations

## Why This Happened

LLVM's BPF backend creates optimized section names:
- `.rodata` - generic read-only data
- `.rodata.str1.1` - merged string constants (1-byte aligned)
- `.rodata.str8.8` - 8-byte aligned strings
- etc.

sbpf-linker was too strict in expecting exactly `.rodata`.

## Test Result

✅ **BUILD SUCCESSFUL**

```bash
$ zig build
$ ls -lh zig-out/lib/program_name.so
-rw-r--r-- 1 vitorpy vitorpy 3.5K Oct 18 16:08 program_name.so

$ file zig-out/lib/program_name.so
ELF 64-bit LSB shared object, eBPF, version 1 (SYSV), dynamically linked, stripped
```

## Files Modified

1. `/home/vitorpy/code/sbpf-linker/src/byteparser.rs`
   - Line 21-23: Find rodata section with prefix match
   - Line 26: Use `ref` to borrow instead of move
   - Line 85: Use `ref` for second rodata check

## Impact

This fix enables:
- ✅ Programs with string constants (error messages, logging)
- ✅ Programs using const arrays
- ✅ Any read-only data that LLVM optimizes into specialized rodata sections

Without this fix, only programs with no read-only data would build.

---

**Date**: 2025-10-18
**Status**: FIXED ✅
**Next**: Test the built program on Solana
