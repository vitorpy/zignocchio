//! Program Derived Addresses (PDAs)

const std = @import("std");
const types = @import("types.zig");
const errors = @import("errors.zig");
const syscalls = @import("syscalls.zig");

const Pubkey = types.Pubkey;
const PUBKEY_BYTES = types.PUBKEY_BYTES;

/// Maximum number of seeds for PDA derivation
pub const MAX_SEEDS: usize = 16;

/// Maximum length of a single seed
pub const MAX_SEED_LEN: usize = 32;

/// Marker for program derived addresses
pub const PDA_MARKER: []const u8 = "ProgramDerivedAddress";

/// Find a valid program derived address and its bump seed
///
/// This function searches for a valid PDA by trying bump seeds from 255 down to 0.
/// The first valid address found is returned along with its bump seed.
///
/// # Arguments
/// * `seeds` - Slice of seed slices used to derive the address
/// * `program_id` - The program ID to use for derivation
///
/// # Returns
/// Tuple of (derived address, bump seed) or error if no valid address found
pub fn findProgramAddress(
    seeds: []const []const u8,
    program_id: *const Pubkey,
) errors.ProgramResult!struct { Pubkey, u8 } {
    var address: Pubkey = undefined;
    var bump_seed: u8 = 255;

    const result = syscalls.sol_try_find_program_address(
        @as([*]const u8, @ptrCast(seeds.ptr)),
        seeds.len,
        @as([*]const u8, @ptrCast(program_id)),
        &address,
        &bump_seed,
    );

    if (result == errors.SUCCESS) {
        return .{ address, bump_seed };
    }

    return error.MaxSeedLengthExceeded;
}

/// Create a program derived address without searching for a bump seed
///
/// This function is useful for verifying that a known set of seeds plus bump seed
/// produces the expected address.
///
/// # Arguments
/// * `seeds` - Slice of seed slices used to derive the address
/// * `program_id` - The program ID to use for derivation
///
/// # Returns
/// The derived address or error if invalid
pub fn createProgramAddress(
    seeds: []const []const u8,
    program_id: *const Pubkey,
) errors.ProgramResult!Pubkey {
    // Validate seeds
    if (seeds.len > MAX_SEEDS) {
        return error.MaxSeedLengthExceeded;
    }

    for (seeds) |seed| {
        if (seed.len > MAX_SEED_LEN) {
            return error.MaxSeedLengthExceeded;
        }
    }

    var address: Pubkey = undefined;

    const result = syscalls.sol_create_program_address(
        @as([*]const u8, @ptrCast(seeds.ptr)),
        seeds.len,
        @as([*]const u8, @ptrCast(program_id)),
        &address,
    );

    if (result == errors.SUCCESS) {
        return address;
    }

    return error.InvalidArgument;
}

/// Derive a pubkey from another pubkey, seed, and program ID using SHA256
pub fn createWithSeed(
    base: *const Pubkey,
    seed: []const u8,
    program_id: *const Pubkey,
) errors.ProgramResult!Pubkey {
    if (seed.len > MAX_SEED_LEN) {
        return error.MaxSeedLengthExceeded;
    }

    // Check if program_id ends with PDA_MARKER
    if (std.mem.endsWith(u8, program_id, PDA_MARKER)) {
        return error.IllegalOwner;
    }

    var address: Pubkey = undefined;

    // Create array of inputs for hashing
    const vals = [_][]const u8{ base[0..], seed, program_id[0..] };

    _ = syscalls.sol_sha256(
        @as([*]const u8, @ptrCast(&vals)),
        vals.len,
        &address,
    );

    return address;
}
