//! SPL Token instruction builders
//!
//! This module provides instruction builder types for all SPL Token program instructions.

// Re-export instruction builders
pub const initialize_mint = @import("initialize_mint.zig");
pub const initialize_account = @import("initialize_account.zig");
pub const transfer = @import("transfer.zig");
pub const mint_to = @import("mint_to.zig");
pub const burn = @import("burn.zig");

// Re-export commonly used types
pub const InitializeMint = initialize_mint.InitializeMint;
pub const InitializeMint2 = initialize_mint.InitializeMint2;
pub const InitializeAccount = initialize_account.InitializeAccount;
pub const InitializeAccount2 = initialize_account.InitializeAccount2;
pub const InitializeAccount3 = initialize_account.InitializeAccount3;
pub const Transfer = transfer.Transfer;
pub const MintTo = mint_to.MintTo;
pub const MintToChecked = mint_to.MintToChecked;
pub const Burn = burn.Burn;
pub const BurnChecked = burn.BurnChecked;
