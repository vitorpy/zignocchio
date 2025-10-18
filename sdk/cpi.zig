//! Cross-Program Invocation (CPI)

const std = @import("std");
const types = @import("types.zig");
const errors = @import("errors.zig");
const syscalls = @import("syscalls.zig");

const Pubkey = types.Pubkey;
const AccountInfo = types.AccountInfo;

/// Account metadata for instructions
pub const AccountMeta = extern struct {
    /// Public key of the account
    pubkey: *const Pubkey,
    /// Is this account a signer
    is_signer: bool,
    /// Is this account writable
    is_writable: bool,
};

/// Instruction for cross-program invocation
pub const Instruction = extern struct {
    /// Program ID to invoke
    program_id: *const Pubkey,
    /// Accounts required by the instruction
    accounts: []const AccountMeta,
    /// Instruction data
    data: []const u8,
};

/// Invoke another program
///
/// # Arguments
/// * `instruction` - The instruction to invoke
/// * `accounts` - Account infos required by the instruction
///
/// # Errors
/// Returns error if the invocation fails
pub fn invoke(
    instruction: *const Instruction,
    accounts: []const AccountInfo,
) errors.ProgramResult!void {
    return invokeSigned(instruction, accounts, &[_][]const u8{});
}

/// Invoke another program with program derived address signatures
///
/// # Arguments
/// * `instruction` - The instruction to invoke
/// * `accounts` - Account infos required by the instruction
/// * `signers_seeds` - Seeds used to derive PDAs that should sign
///
/// # Errors
/// Returns error if the invocation fails
pub fn invokeSigned(
    instruction: *const Instruction,
    accounts: []const AccountInfo,
    signers_seeds: []const []const u8,
) errors.ProgramResult!void {
    // Validate that accounts in instruction match provided account infos
    for (instruction.accounts) |account_meta| {
        var found = false;
        for (accounts) |account_info| {
            if (types.pubkeyEq(account_meta.pubkey, account_info.key())) {
                found = true;

                // Check borrow state before CPI
                if (account_meta.is_writable) {
                    try account_info.canBorrowMutData();
                }
                break;
            }
        }
        if (!found) {
            return error.NotEnoughAccountKeys;
        }
    }

    const result = syscalls.sol_invoke_signed_rust(
        @as([*]const u8, @ptrCast(instruction)),
        @as([*]const u8, @ptrCast(accounts.ptr)),
        accounts.len,
        @as([*]const u8, @ptrCast(signers_seeds.ptr)),
        signers_seeds.len,
    );

    if (result != errors.SUCCESS) {
        return error.InvalidArgument;
    }
}

/// Set return data for this program
///
/// The return data can be retrieved by the caller or by sibling instructions
/// in the same transaction.
pub fn setReturnData(data: []const u8) void {
    syscalls.sol_set_return_data(data.ptr, data.len);
}

/// Get return data from the last CPI call
///
/// Returns a tuple of (program_id, data) if return data exists, or null otherwise
pub fn getReturnData(buffer: []u8) ?struct { Pubkey, []const u8 } {
    var program_id: Pubkey = undefined;

    const len = syscalls.sol_get_return_data(
        buffer.ptr,
        buffer.len,
        &program_id,
    );

    if (len == 0) {
        return null;
    }

    return .{ program_id, buffer[0..@intCast(len)] };
}
