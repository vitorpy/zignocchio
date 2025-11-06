//! Cross-Program Invocation (CPI)

const std = @import("std");
const types = @import("types.zig");
const errors = @import("errors.zig");
const syscalls = @import("syscalls.zig");

const Pubkey = types.Pubkey;
const AccountInfo = types.AccountInfo;

/// Account metadata for instructions
/// NOTE: Field order must match C ABI (SolAccountMeta in sol/cpi.h)
pub const AccountMeta = extern struct {
    /// Public key of the account
    pubkey: *const Pubkey,
    /// Is this account writable (MUST be before is_signer for C ABI compatibility)
    is_writable: bool,
    /// Is this account a signer
    is_signer: bool,
};

/// Instruction for cross-program invocation
pub const Instruction = struct {
    /// Program ID to invoke
    program_id: *const Pubkey,
    /// Accounts required by the instruction
    accounts: []const AccountMeta,
    /// Instruction data
    data: []const u8,
};

// =============================================================================
// C-ABI Structures for syscalls
// These must match the exact memory layout expected by sol_invoke_signed_c
// =============================================================================

/// C-ABI instruction format (SolInstruction in sol/cpi.h)
const SolInstruction = extern struct {
    program_id: *const Pubkey,
    accounts: [*]const AccountMeta,
    account_len: u64,
    data: [*]const u8,
    data_len: u64,
};

/// C-ABI signer seed (SolSignerSeedC in Agave)
/// Represents a single seed byte array with pointer and length
const SolSignerSeedC = extern struct {
    addr: u64, // Pointer to seed bytes
    len: u64, // Length of seed bytes
};

/// C-ABI signer seeds (SolSignerSeedsC in Agave)
/// Represents an array of seeds for one PDA derivation
const SolSignerSeedsC = extern struct {
    addr: u64, // Pointer to array of SolSignerSeedC
    len: u64, // Number of seeds
};

/// C-ABI account info format (SolAccountInfo in sol/entrypoint.h)
const SolAccountInfo = extern struct {
    key: *const Pubkey,
    lamports: *u64,
    data_len: u64,
    data: [*]u8,
    owner: *const Pubkey,
    rent_epoch: u64,
    is_signer: bool,
    is_writable: bool,
    executable: bool,
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
) errors.ProgramResult {
    return invokeSigned(instruction, accounts, &[_][]const u8{});
}

/// Invoke another program with program derived address signatures
///
/// # Arguments
/// * `instruction` - The instruction to invoke
/// * `accounts` - Account infos required by the instruction
/// * `signers_seeds` - Seeds used to derive PDAs that should sign (array of seed arrays)
///
/// # Errors
/// Returns error if the invocation fails
pub fn invokeSigned(
    instruction: *const Instruction,
    accounts: []const AccountInfo,
    signers_seeds: []const []const u8,
) errors.ProgramResult {
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

    // Convert instruction to C ABI format
    const sol_instruction = SolInstruction{
        .program_id = instruction.program_id,
        .accounts = instruction.accounts.ptr,
        .account_len = instruction.accounts.len,
        .data = instruction.data.ptr,
        .data_len = instruction.data.len,
    };

    // Convert AccountInfo array to SolAccountInfo C ABI format
    // The syscall expects SolAccountInfo, not our AccountInfo wrapper
    // Using small array to avoid sBPF stack overflow (4KB limit)
    var sol_account_infos: [4]SolAccountInfo = undefined;
    if (accounts.len > sol_account_infos.len) {
        return error.InvalidArgument;
    }

    // Convert AccountInfo to SolAccountInfo format
    // Memory layout: [Account struct][account data immediately after]
    for (accounts, 0..) |account_info, i| {
        const account = account_info.raw;

        // Data follows immediately after Account struct
        const data_ptr: [*]u8 = @ptrFromInt(@intFromPtr(account) + @sizeOf(types.Account));

        sol_account_infos[i] = SolAccountInfo{
            .key = &account.key,
            .lamports = &account.lamports,
            .data_len = account.data_len,
            .data = data_ptr,
            .owner = &account.owner,
            .rent_epoch = 0, // Not used in CPI
            .is_signer = account.is_signer != 0,
            .is_writable = account.is_writable != 0,
            .executable = account.executable != 0,
        };
    }

    // Serialize signer seeds to C ABI format if provided
    // For single PDA signing (most common case), seeds are passed as a single array
    // Using small array to avoid sBPF stack overflow
    var sol_signer_seeds: [4]SolSignerSeedC = undefined;
    var sol_signers: [1]SolSignerSeedsC = undefined;

    const signers_ptr: [*]const u8 = if (signers_seeds.len > 0) blk: {
        // Convert each seed to SolSignerSeedC
        if (signers_seeds.len > sol_signer_seeds.len) {
            return error.InvalidArgument;
        }

        for (signers_seeds, 0..) |seed, i| {
            sol_signer_seeds[i] = SolSignerSeedC{
                .addr = @intFromPtr(seed.ptr),
                .len = seed.len,
            };
        }

        // Create the signers array (one PDA)
        sol_signers[0] = SolSignerSeedsC{
            .addr = @intFromPtr(&sol_signer_seeds),
            .len = signers_seeds.len,
        };

        break :blk @as([*]const u8, @ptrCast(&sol_signers));
    } else blk: {
        break :blk @as([*]const u8, @ptrCast(&sol_signers));
    };

    const signers_len: u64 = if (signers_seeds.len > 0) 1 else 0;

    const result = syscalls.sol_invoke_signed_c(
        @as([*]const u8, @ptrCast(&sol_instruction)),
        @as([*]const u8, @ptrCast(&sol_account_infos)),
        accounts.len,
        signers_ptr,
        signers_len,
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
