//! Solana program entrypoint and input deserialization

const std = @import("std");
const types = @import("types.zig");
const errors = @import("errors.zig");

const Pubkey = types.Pubkey;
const Account = types.Account;
const AccountInfo = types.AccountInfo;
const NON_DUP_MARKER = types.NON_DUP_MARKER;
const MAX_PERMITTED_DATA_INCREASE = types.MAX_PERMITTED_DATA_INCREASE;
const BPF_ALIGN_OF_U128 = types.BPF_ALIGN_OF_U128;

/// Heap start address for BPF programs
pub const HEAP_START_ADDRESS: u64 = 0x300000000;

/// Heap length (32KB)
pub const HEAP_LENGTH: usize = 32 * 1024;

/// Static account data size (account header + max data increase)
const STATIC_ACCOUNT_DATA: usize = @sizeOf(Account) + MAX_PERMITTED_DATA_INCREASE;

/// Align pointer to BPF u128 alignment
inline fn alignPointer(ptr: usize) usize {
    return (ptr + (BPF_ALIGN_OF_U128 - 1)) & ~(BPF_ALIGN_OF_U128 - 1);
}

/// Deserialize the input buffer into program_id, accounts, and instruction_data
///
/// This function performs zero-copy deserialization of the Solana input buffer.
/// All returned values are pointers/slices into the original input buffer.
///
/// # Arguments
/// * `input` - Raw pointer to the input buffer from Solana runtime
/// * `accounts_buffer` - Pre-allocated buffer to store AccountInfo structs
///
/// # Returns
/// Tuple of (program_id, accounts slice, instruction_data slice)
pub fn deserialize(
    input: [*]u8,
    accounts_buffer: []AccountInfo,
) struct { *const Pubkey, []AccountInfo, []const u8 } {
    var ptr = input;
    const max_accounts = accounts_buffer.len;

    // Read number of accounts
    const num_accounts_ptr = @as(*const u64, @ptrCast(@alignCast(ptr)));
    var num_accounts: usize = @intCast(num_accounts_ptr.*);
    ptr += @sizeOf(u64);

    var accounts_count: usize = 0;

    if (num_accounts > 0) {
        // Limit to buffer capacity
        const to_process = if (num_accounts > max_accounts) max_accounts else num_accounts;
        var to_skip = num_accounts - to_process;

        var i: usize = 0;
        while (i < to_process) : (i += 1) {
            const account_ptr = @as(*Account, @ptrCast(@alignCast(ptr)));

            // Skip 8 bytes (rent epoch or duplicate marker + padding)
            ptr += @sizeOf(u64);

            if (account_ptr.borrow_state != NON_DUP_MARKER) {
                // Duplicate account - reference existing account
                const dup_index = account_ptr.borrow_state;
                accounts_buffer[i] = accounts_buffer[dup_index];
            } else {
                // New account
                accounts_buffer[i] = AccountInfo{ .raw = account_ptr };

                // Skip account struct + data
                ptr += STATIC_ACCOUNT_DATA;
                ptr += @as(usize, @intCast(account_ptr.data_len));

                // Align to u128
                ptr = @ptrFromInt(alignPointer(@intFromPtr(ptr)));
            }
            accounts_count += 1;
        }

        // Skip remaining accounts if buffer was too small
        while (to_skip > 0) : (to_skip -= 1) {
            const account_ptr = @as(*Account, @ptrCast(@alignCast(ptr)));
            ptr += @sizeOf(u64);

            if (account_ptr.borrow_state == NON_DUP_MARKER) {
                ptr += STATIC_ACCOUNT_DATA;
                ptr += @as(usize, @intCast(account_ptr.data_len));
                ptr = @ptrFromInt(alignPointer(@intFromPtr(ptr)));
            }
        }
    }

    // Read instruction data length
    const ix_data_len_ptr = @as(*const u64, @ptrCast(@alignCast(ptr)));
    const ix_data_len: usize = @intCast(ix_data_len_ptr.*);
    ptr += @sizeOf(u64);

    // Get instruction data slice
    const instruction_data = ptr[0..ix_data_len];
    ptr += ix_data_len;

    // Get program ID
    const program_id = @as(*const Pubkey, @ptrCast(@alignCast(ptr)));

    return .{
        program_id,
        accounts_buffer[0..accounts_count],
        instruction_data,
    };
}

/// Entrypoint function signature
pub const EntrypointFn = *const fn (
    program_id: *const Pubkey,
    accounts: []AccountInfo,
    instruction_data: []const u8,
) errors.ProgramResult;

/// Create a program entrypoint with custom max accounts
pub fn entrypoint(
    comptime max_accounts: usize,
    comptime process_instruction: EntrypointFn,
) fn ([*]u8) callconv(.C) u64 {
    return struct {
        fn entry(input: [*]u8) callconv(.C) u64 {
            var accounts_buffer: [max_accounts]AccountInfo = undefined;

            const program_id, const accounts, const instruction_data =
                deserialize(input, &accounts_buffer);

            process_instruction(program_id, accounts, instruction_data) catch |err| {
                return errors.errorToU64(err);
            };

            return errors.SUCCESS;
        }
    }.entry;
}
