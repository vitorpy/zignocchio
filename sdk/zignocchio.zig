//! # Zignocchio
//!
//! A zero-dependency Zig SDK for building Solana programs.
//!
//! ## Features
//! - Zero dependencies
//! - Zero-copy input deserialization
//! - Efficient borrow tracking
//! - Type-safe API
//! - Minimal compute unit consumption
//!
//! ## Example
//! ```zig
//! const sdk = @import("sdk/zignocchio.zig");
//!
//! export fn entrypoint(input: [*]u8) u64 {
//!     return @call(.always_inline, sdk.entrypoint(10, processInstruction), .{input});
//! }
//!
//! fn processInstruction(
//!     program_id: *const sdk.Pubkey,
//!     accounts: []sdk.AccountInfo,
//!     instruction_data: []const u8,
//! ) sdk.ProgramResult {
//!     sdk.log("Hello from Zignocchio!");
//!     return .{};
//! }
//! ```

// Re-export all modules
pub const errors = @import("errors.zig");
pub const types = @import("types.zig");
pub const syscalls = @import("syscalls.zig");
pub const log = @import("log.zig");
pub const entrypoint = @import("entrypoint.zig");
pub const allocator = @import("allocator.zig");
pub const pda = @import("pda.zig");
pub const cpi = @import("cpi.zig");
pub const token = @import("token.zig");

// Re-export commonly used types
pub const ProgramError = errors.ProgramError;
pub const ProgramResult = errors.ProgramResult;
pub const SUCCESS = errors.SUCCESS;

pub const Pubkey = types.Pubkey;
pub const Account = types.Account;
pub const AccountInfo = types.AccountInfo;
pub const BorrowState = types.BorrowState;
pub const Ref = types.Ref;
pub const RefMut = types.RefMut;

pub const PUBKEY_BYTES = types.PUBKEY_BYTES;
pub const MAX_TX_ACCOUNTS = types.MAX_TX_ACCOUNTS;
pub const NON_DUP_MARKER = types.NON_DUP_MARKER;
pub const MAX_PERMITTED_DATA_INCREASE = types.MAX_PERMITTED_DATA_INCREASE;

// Re-export utility functions
pub const pubkeyEq = types.pubkeyEq;
pub const deserialize = entrypoint.deserialize;

// Re-export logging
pub const logMsg = log.log;
pub const logU64 = log.logU64;
pub const log64 = log.log64;
pub const logPubkey = log.logPubkey;
pub const logComputeUnits = log.logComputeUnits;
pub const getRemainingComputeUnits = log.getRemainingComputeUnits;

// Re-export allocator
pub const BumpAllocator = allocator.BumpAllocator;

// Re-export PDA functions
pub const findProgramAddress = pda.findProgramAddress;
pub const createProgramAddress = pda.createProgramAddress;
pub const createWithSeed = pda.createWithSeed;
pub const MAX_SEEDS = pda.MAX_SEEDS;
pub const MAX_SEED_LEN = pda.MAX_SEED_LEN;

// Re-export CPI
pub const AccountMeta = cpi.AccountMeta;
pub const Instruction = cpi.Instruction;
pub const invoke = cpi.invoke;
pub const invokeSigned = cpi.invokeSigned;
pub const setReturnData = cpi.setReturnData;
pub const getReturnData = cpi.getReturnData;

/// Create a program entrypoint with default max accounts (254)
pub fn createEntrypoint(
    comptime process_instruction: entrypoint.EntrypointFn,
) fn ([*]u8) callconv(.c) u64 {
    return entrypoint.entrypoint(MAX_TX_ACCOUNTS, process_instruction);
}

/// Create a program entrypoint with custom max accounts
pub fn createEntrypointWithMaxAccounts(
    comptime max_accounts: usize,
    comptime process_instruction: entrypoint.EntrypointFn,
) fn ([*]u8) callconv(.c) u64 {
    return entrypoint.entrypoint(max_accounts, process_instruction);
}
