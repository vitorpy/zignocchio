//! Minimal test for global constant references in BPF
//!
//! This program tests whether global constants cause crashes in Solana BPF runtime.
//! Based on issue zignocchio-7acb: TOKEN_PROGRAM_ID crash investigation.

const sdk = @import("sdk");
const constants = @import("constants.zig");
const helper = @import("helper.zig");

// Test 1: Simple global constant (32 bytes like Pubkey)
pub const GLOBAL_CONST: [32]u8 = .{
    0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
    0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
    0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
    0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20,
};

// Test 3: Exact TOKEN_PROGRAM_ID constant (TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA)
pub const TOKEN_PROGRAM_ID: [32]u8 = .{
    0x06, 0xdd, 0xf6, 0xe1, 0xd7, 0x65, 0xa1, 0x93,
    0xd9, 0xcb, 0xe1, 0x46, 0xce, 0xeb, 0x79, 0xac,
    0x1c, 0xb4, 0x85, 0xed, 0x5f, 0x5b, 0x37, 0x91,
    0x3a, 0x8c, 0xf5, 0x85, 0x7e, 0xff, 0x00, 0xa9,
};

// Test 2: Inline function returning constant (workaround)
pub inline fn getConstant() *const [32]u8 {
    const local: [32]u8 = .{
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
        0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20,
    };
    return &local;
}

/// Program entrypoint
export fn entrypoint(input: [*]u8) u64 {
    return @call(.always_inline, sdk.createEntrypointWithMaxAccounts(10, processInstruction), .{input});
}

/// Process instruction - tests different global constant scenarios
fn processInstruction(
    _: *const sdk.Pubkey,
    _: []sdk.AccountInfo,
    instruction_data: []const u8,
) sdk.ProgramResult {
    sdk.logMsg("Global Test: Starting");

    if (instruction_data.len == 0) {
        sdk.logMsg("Error: Empty instruction data");
        return error.InvalidInstructionData;
    }

    const test_type = instruction_data[0];

    sdk.logMsg("Test type:");
    sdk.logU64(test_type);

    switch (test_type) {
        0 => {
            // Test 0: No global reference (baseline)
            sdk.logMsg("Test 0: Baseline - no global reference");
            const local_data: [32]u8 = .{
                0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
                0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
                0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20,
            };
            _ = local_data;
            sdk.logMsg("Test 0: PASSED");
        },
        1 => {
            // Test 1: Reference global constant
            sdk.logMsg("Test 1: Referencing global constant");
            const ptr = &GLOBAL_CONST;
            _ = ptr;
            sdk.logMsg("Test 1: PASSED");
        },
        2 => {
            // Test 2: Use inline function workaround
            sdk.logMsg("Test 2: Using inline function workaround");
            const ptr = getConstant();
            _ = ptr;
            sdk.logMsg("Test 2: PASSED");
        },
        3 => {
            // Test 3: Reference TOKEN_PROGRAM_ID specifically
            sdk.logMsg("Test 3: Referencing TOKEN_PROGRAM_ID");
            const ptr = &TOKEN_PROGRAM_ID;
            _ = ptr;
            sdk.logMsg("Test 3: PASSED");
        },
        4 => {
            // Test 4: Reference TOKEN_PROGRAM_ID from another module (cross-module)
            sdk.logMsg("Test 4: Cross-module TOKEN_PROGRAM_ID reference");
            const ptr = &constants.TOKEN_PROGRAM_ID;
            _ = ptr;
            sdk.logMsg("Test 4: PASSED");
        },
        5 => {
            // Test 5: Use helper function that references TOKEN_PROGRAM_ID (like SDK)
            sdk.logMsg("Test 5: Helper function with TOKEN_PROGRAM_ID");
            var buffer: [32]u8 = undefined;
            helper.buildInstructionData(&buffer);
            sdk.logMsg("Test 5: PASSED");
        },
        else => {
            sdk.logMsg("Error: Unknown test type");
            return error.InvalidInstructionData;
        },
    }

    sdk.logMsg("Global Test: SUCCESS");
    return;
}
