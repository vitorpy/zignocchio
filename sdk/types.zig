//! Core Solana types

const std = @import("std");
const errors = @import("errors.zig");

/// Number of bytes in a pubkey
pub const PUBKEY_BYTES: usize = 32;

/// Public key type
pub const Pubkey = [PUBKEY_BYTES]u8;

/// Maximum number of accounts in a transaction
pub const MAX_TX_ACCOUNTS: usize = 254; // u8::MAX - 1

/// Value used to indicate that a serialized account is not a duplicate
pub const NON_DUP_MARKER: u8 = 0xFF;

/// Maximum permitted data increase per instruction
pub const MAX_PERMITTED_DATA_INCREASE: usize = 10 * 1024;

/// BPF alignment for u128
pub const BPF_ALIGN_OF_U128: usize = 8;

/// Compare two pubkeys for equality (optimized)
pub fn pubkeyEq(p1: *const Pubkey, p2: *const Pubkey) bool {
    const p1_ptr = @as([*]const u64, @ptrCast(@alignCast(p1)));
    const p2_ptr = @as([*]const u64, @ptrCast(@alignCast(p2)));

    return p1_ptr[0] == p2_ptr[0] and
           p1_ptr[1] == p2_ptr[1] and
           p1_ptr[2] == p2_ptr[2] and
           p1_ptr[3] == p2_ptr[3];
}

/// Raw account data structure (matches Solana's memory layout)
pub const Account = extern struct {
    /// Borrow state for lamports and account data (bit-packed)
    ///
    /// Bits 7-4: lamport borrows (1 mut flag + 3 bits for count 0-7)
    /// Bits 3-0: data borrows (1 mut flag + 3 bits for count 0-7)
    ///
    /// Initial state: 0b_1111_1111 (NON_DUP_MARKER)
    borrow_state: u8,

    /// Indicates whether the transaction was signed by this account
    is_signer: u8,

    /// Indicates whether the account is writable
    is_writable: u8,

    /// Indicates whether this account represents a program
    executable: u8,

    /// Difference between original and current data length
    resize_delta: i32,

    /// Public key of the account
    key: Pubkey,

    /// Program that owns this account
    owner: Pubkey,

    /// The lamports in the account
    lamports: u64,

    /// Length of the data
    data_len: u64,

    // Account data follows immediately in memory after this struct
};

/// Borrow state masks
pub const BorrowState = enum(u8) {
    /// Mask to check if account is borrowed (any borrow)
    Borrowed = 0b_1111_1111,
    /// Mask to check if account is mutably borrowed
    MutablyBorrowed = 0b_1000_1000,
};

/// Bit shift for lamports borrow tracking
const LAMPORTS_BORROW_SHIFT: u8 = 4;

/// Bit shift for data borrow tracking
const DATA_BORROW_SHIFT: u8 = 0;

/// Bitmask for lamports mutable borrow flag
const LAMPORTS_MUTABLE_BORROW_BITMASK: u8 = 0b_1000_0000;

/// Bitmask for data mutable borrow flag
const DATA_MUTABLE_BORROW_BITMASK: u8 = 0b_0000_1000;

/// Wrapper for Account providing safe access
pub const AccountInfo = struct {
    /// Pointer to raw account data
    raw: *Account,

    // Accessor methods

    /// Get public key
    pub fn key(self: AccountInfo) *const Pubkey {
        return &self.raw.key;
    }

    /// Get owner
    pub fn owner(self: AccountInfo) *const Pubkey {
        return &self.raw.owner;
    }

    /// Check if signer
    pub fn isSigner(self: AccountInfo) bool {
        return self.raw.is_signer != 0;
    }

    /// Check if writable
    pub fn isWritable(self: AccountInfo) bool {
        return self.raw.is_writable != 0;
    }

    /// Check if executable
    pub fn executable(self: AccountInfo) bool {
        return self.raw.executable != 0;
    }

    /// Get data length
    pub fn dataLen(self: AccountInfo) usize {
        return @intCast(self.raw.data_len);
    }

    /// Get resize delta
    pub fn resizeDelta(self: AccountInfo) i32 {
        return self.raw.resize_delta;
    }

    /// Get lamports
    pub fn lamports(self: AccountInfo) u64 {
        return self.raw.lamports;
    }

    /// Check if data is empty
    pub fn dataIsEmpty(self: AccountInfo) bool {
        return self.dataLen() == 0;
    }

    /// Check if owned by program
    pub fn isOwnedBy(self: AccountInfo, program: *const Pubkey) bool {
        return pubkeyEq(self.owner(), program);
    }

    /// Check if account is borrowed
    pub fn isBorrowed(self: AccountInfo, state: BorrowState) bool {
        const borrow_state = self.raw.borrow_state;
        const mask = @intFromEnum(state);
        return (borrow_state & mask) != mask;
    }

    /// Get pointer to account data
    pub fn dataPtr(self: AccountInfo) [*]u8 {
        const ptr = @intFromPtr(self.raw);
        return @ptrFromInt(ptr + @sizeOf(Account));
    }

    // Borrow checking methods

    /// Check if can borrow data immutably
    pub fn canBorrowData(self: AccountInfo) errors.ProgramResult!void {
        const borrow_state = self.raw.borrow_state;

        // Check if mutably borrowed
        if (borrow_state & DATA_MUTABLE_BORROW_BITMASK == 0) {
            return error.AccountBorrowFailed;
        }

        // Check if max immutable borrows reached
        if (borrow_state & 0b_0000_0111 == 0) {
            return error.AccountBorrowFailed;
        }
    }

    /// Check if can borrow data mutably
    pub fn canBorrowMutData(self: AccountInfo) errors.ProgramResult!void {
        const borrow_state = self.raw.borrow_state;

        // Check if any borrow exists
        if (borrow_state & 0b_0000_1111 != 0b_0000_1111) {
            return error.AccountBorrowFailed;
        }
    }

    /// Check if can borrow lamports immutably
    pub fn canBorrowLamports(self: AccountInfo) errors.ProgramResult!void {
        const borrow_state = self.raw.borrow_state;

        // Check if mutably borrowed
        if (borrow_state & LAMPORTS_MUTABLE_BORROW_BITMASK == 0) {
            return error.AccountBorrowFailed;
        }

        // Check if max immutable borrows reached
        if (borrow_state & 0b_0111_0000 == 0) {
            return error.AccountBorrowFailed;
        }
    }

    /// Check if can borrow lamports mutably
    pub fn canBorrowMutLamports(self: AccountInfo) errors.ProgramResult!void {
        const borrow_state = self.raw.borrow_state;

        // Check if any borrow exists
        if (borrow_state & 0b_1111_0000 != 0b_1111_0000) {
            return error.AccountBorrowFailed;
        }
    }

    // Unsafe unchecked borrows (for when you've verified no duplicates)

    /// Borrow data immutably without checking (unsafe)
    pub fn borrowDataUnchecked(self: AccountInfo) []const u8 {
        const ptr = self.dataPtr();
        return ptr[0..self.dataLen()];
    }

    /// Borrow data mutably without checking (unsafe)
    pub fn borrowMutDataUnchecked(self: AccountInfo) []u8 {
        const ptr = self.dataPtr();
        return ptr[0..self.dataLen()];
    }

    /// Borrow lamports immutably without checking (unsafe)
    pub fn borrowLamportsUnchecked(self: AccountInfo) *const u64 {
        return &self.raw.lamports;
    }

    /// Borrow lamports mutably without checking (unsafe)
    pub fn borrowMutLamportsUnchecked(self: AccountInfo) *u64 {
        return &self.raw.lamports;
    }

    // Safe borrows with RAII guards

    /// Borrow data immutably
    pub fn tryBorrowData(self: AccountInfo) errors.ProgramResult!Ref([]const u8) {
        try self.canBorrowData();

        const borrow_state_ptr = @as(*u8, @ptrCast(&self.raw.borrow_state));
        // Decrement immutable borrow count
        borrow_state_ptr.* -= 1 << DATA_BORROW_SHIFT;

        const ptr = self.dataPtr();
        return Ref([]const u8){
            .value = ptr[0..self.dataLen()],
            .state = borrow_state_ptr,
            .borrow_shift = DATA_BORROW_SHIFT,
        };
    }

    /// Borrow data mutably
    pub fn tryBorrowMutData(self: AccountInfo) errors.ProgramResult!RefMut([]u8) {
        try self.canBorrowMutData();

        const borrow_state_ptr = @as(*u8, @ptrCast(&self.raw.borrow_state));
        // Set mutable borrow bit to 0
        borrow_state_ptr.* &= 0b_1111_0111;

        const ptr = self.dataPtr();
        return RefMut([]u8){
            .value = ptr[0..self.dataLen()],
            .state = borrow_state_ptr,
            .borrow_bitmask = DATA_MUTABLE_BORROW_BITMASK,
        };
    }

    /// Borrow lamports immutably
    pub fn tryBorrowLamports(self: AccountInfo) errors.ProgramResult!Ref(*const u64) {
        try self.canBorrowLamports();

        const borrow_state_ptr = @as(*u8, @ptrCast(&self.raw.borrow_state));
        // Decrement immutable borrow count
        borrow_state_ptr.* -= 1 << LAMPORTS_BORROW_SHIFT;

        return Ref(*const u64){
            .value = &self.raw.lamports,
            .state = borrow_state_ptr,
            .borrow_shift = LAMPORTS_BORROW_SHIFT,
        };
    }

    /// Borrow lamports mutably
    pub fn tryBorrowMutLamports(self: AccountInfo) errors.ProgramResult!RefMut(*u64) {
        try self.canBorrowMutLamports();

        const borrow_state_ptr = @as(*u8, @ptrCast(&self.raw.borrow_state));
        // Set mutable borrow bit to 0
        borrow_state_ptr.* &= 0b_0111_1111;

        return RefMut(*u64){
            .value = &self.raw.lamports,
            .state = borrow_state_ptr,
            .borrow_bitmask = LAMPORTS_MUTABLE_BORROW_BITMASK,
        };
    }

    /// Assign new owner (unsafe - must ensure no active references)
    pub fn assign(self: AccountInfo, new_owner: *const Pubkey) void {
        self.raw.owner = new_owner.*;
    }
};

/// RAII guard for immutable borrows
pub fn Ref(comptime T: type) type {
    return struct {
        value: T,
        state: *u8,
        borrow_shift: u8,

        const Self = @This();

        /// Release the borrow
        pub fn release(self: *Self) void {
            // Increment borrow count back
            self.state.* += 1 << self.borrow_shift;
        }
    };
}

/// RAII guard for mutable borrows
pub fn RefMut(comptime T: type) type {
    return struct {
        value: T,
        state: *u8,
        borrow_bitmask: u8,

        const Self = @This();

        /// Release the borrow
        pub fn release(self: *Self) void {
            // Set mutable borrow bit back to 1
            self.state.* |= self.borrow_bitmask;
        }
    };
}
