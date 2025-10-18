//! Counter Program - Example using Zignocchio SDK
//!
//! This program demonstrates:
//! - Using the zignocchio SDK
//! - Zero-copy account borrowing
//! - Safe mutable data access
//! - Logging and error handling

const sdk = @import("../sdk/zignocchio.zig");

/// Program entrypoint
export fn entrypoint(input: [*]u8) u64 {
    return @call(.always_inline, sdk.createEntrypointWithMaxAccounts(5, processInstruction), .{input});
}

/// Process instruction
fn processInstruction(
    program_id: *const sdk.Pubkey,
    accounts: []sdk.AccountInfo,
    instruction_data: []const u8,
) sdk.ProgramResult {
    sdk.logMsg("Counter program: starting");

    // Expecting at least 1 account (the counter account)
    if (accounts.len < 1) {
        sdk.logMsg("Error: Not enough accounts");
        return error.NotEnoughAccountKeys;
    }

    const counter_account = accounts[0];

    // Verify the account is writable
    if (!counter_account.isWritable()) {
        sdk.logMsg("Error: Counter account not writable");
        return error.ImmutableAccount;
    }

    // Verify the account is owned by this program
    if (!counter_account.isOwnedBy(program_id)) {
        sdk.logMsg("Error: Counter account not owned by program");
        return error.IncorrectProgramId;
    }

    // Verify the account has enough space for a u64
    if (counter_account.dataLen() < 8) {
        sdk.logMsg("Error: Counter account too small");
        return error.AccountDataTooSmall;
    }

    // Borrow the account data mutably
    var data = try counter_account.tryBorrowMutData();
    defer data.release();

    // Read current counter value
    const counter_ptr = @as(*u64, @ptrCast(@alignCast(data.value.ptr)));
    const current = counter_ptr.*;

    sdk.logMsg("Current counter value:");
    sdk.logU64(current);

    // Determine operation from instruction data
    if (instruction_data.len > 0) {
        const operation = instruction_data[0];

        switch (operation) {
            0 => {
                // Increment
                if (current == std.math.maxInt(u64)) {
                    sdk.logMsg("Error: Counter overflow");
                    return error.ArithmeticOverflow;
                }
                counter_ptr.* = current + 1;
                sdk.logMsg("Incremented counter");
            },
            1 => {
                // Decrement
                if (current == 0) {
                    sdk.logMsg("Error: Counter underflow");
                    return error.ArithmeticOverflow;
                }
                counter_ptr.* = current - 1;
                sdk.logMsg("Decremented counter");
            },
            2 => {
                // Reset
                counter_ptr.* = 0;
                sdk.logMsg("Reset counter");
            },
            else => {
                sdk.logMsg("Error: Unknown operation");
                return error.InvalidInstructionData;
            },
        }
    } else {
        // Default: increment
        if (current == std.math.maxInt(u64)) {
            sdk.logMsg("Error: Counter overflow");
            return error.ArithmeticOverflow;
        }
        counter_ptr.* = current + 1;
        sdk.logMsg("Incremented counter (default)");
    }

    // Log new value
    sdk.logMsg("New counter value:");
    sdk.logU64(counter_ptr.*);

    // Log remaining compute units
    sdk.logMsg("Remaining compute units:");
    sdk.logU64(sdk.getRemainingComputeUnits());

    return .{};
}

const std = @import("std");
