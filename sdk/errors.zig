//! Error types for Solana programs

/// Program execution errors
pub const ProgramError = error{
    /// Account borrow failed
    AccountBorrowFailed,
    /// Invalid account data
    InvalidAccountData,
    /// Invalid argument
    InvalidArgument,
    /// Invalid instruction data
    InvalidInstructionData,
    /// Missing required signature
    MissingRequiredSignature,
    /// Account already initialized
    AccountAlreadyInitialized,
    /// Uninitialized account
    UninitializedAccount,
    /// Not enough account keys given
    NotEnoughAccountKeys,
    /// Account data too small
    AccountDataTooSmall,
    /// Insufficient funds
    InsufficientFunds,
    /// Incorrect program id
    IncorrectProgramId,
    /// Account not rent exempt
    AccountNotRentExempt,
    /// Invalid realloc
    InvalidRealloc,
    /// Max seed length exceeded
    MaxSeedLengthExceeded,
    /// Illegal owner
    IllegalOwner,
    /// Arithmetic overflow
    ArithmeticOverflow,
    /// Immutable account
    ImmutableAccount,
    /// Incorrect authority
    IncorrectAuthority,
};

/// Success return value
pub const SUCCESS: u64 = 0;

/// Convert ProgramError to u64 error code
pub fn errorToU64(err: ProgramError) u64 {
    return switch (err) {
        ProgramError.AccountBorrowFailed => 1,
        ProgramError.InvalidAccountData => 2,
        ProgramError.InvalidArgument => 3,
        ProgramError.InvalidInstructionData => 4,
        ProgramError.MissingRequiredSignature => 5,
        ProgramError.AccountAlreadyInitialized => 6,
        ProgramError.UninitializedAccount => 7,
        ProgramError.NotEnoughAccountKeys => 8,
        ProgramError.AccountDataTooSmall => 9,
        ProgramError.InsufficientFunds => 10,
        ProgramError.IncorrectProgramId => 11,
        ProgramError.AccountNotRentExempt => 12,
        ProgramError.InvalidRealloc => 13,
        ProgramError.MaxSeedLengthExceeded => 14,
        ProgramError.IllegalOwner => 15,
        ProgramError.ArithmeticOverflow => 16,
        ProgramError.ImmutableAccount => 17,
        ProgramError.IncorrectAuthority => 18,
    };
}

/// Program result type
pub const ProgramResult = error{
    AccountBorrowFailed,
    InvalidAccountData,
    InvalidArgument,
    InvalidInstructionData,
    MissingRequiredSignature,
    AccountAlreadyInitialized,
    UninitializedAccount,
    NotEnoughAccountKeys,
    AccountDataTooSmall,
    InsufficientFunds,
    IncorrectProgramId,
    AccountNotRentExempt,
    InvalidRealloc,
    MaxSeedLengthExceeded,
    IllegalOwner,
    ArithmeticOverflow,
    ImmutableAccount,
    IncorrectAuthority,
}!void;
