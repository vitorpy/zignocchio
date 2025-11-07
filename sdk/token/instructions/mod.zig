//! SPL Token instruction builders
//!
//! This module provides instruction builder types for all SPL Token program instructions.

// Re-export instruction builders
pub const initialize_mint = @import("initialize_mint.zig");
pub const initialize_account = @import("initialize_account.zig");
pub const transfer = @import("transfer.zig");
pub const transfer_checked = @import("transfer_checked.zig");
pub const mint_to = @import("mint_to.zig");
pub const burn = @import("burn.zig");
pub const close_account = @import("close_account.zig");
pub const sync_native = @import("sync_native.zig");
pub const set_authority = @import("set_authority.zig");
pub const freeze = @import("freeze.zig");
pub const revoke = @import("revoke.zig");
pub const approve = @import("approve.zig");

// Re-export commonly used types
pub const InitializeMint = initialize_mint.InitializeMint;
pub const InitializeMint2 = initialize_mint.InitializeMint2;
pub const InitializeAccount = initialize_account.InitializeAccount;
pub const InitializeAccount2 = initialize_account.InitializeAccount2;
pub const InitializeAccount3 = initialize_account.InitializeAccount3;
pub const Transfer = transfer.Transfer;
pub const TransferChecked = transfer_checked.TransferChecked;
pub const MintTo = mint_to.MintTo;
pub const MintToChecked = mint_to.MintToChecked;
pub const Burn = burn.Burn;
pub const BurnChecked = burn.BurnChecked;
pub const CloseAccount = close_account.CloseAccount;
pub const SyncNative = sync_native.SyncNative;
pub const SetAuthority = set_authority.SetAuthority;
pub const AuthorityType = set_authority.AuthorityType;
pub const FreezeAccount = freeze.FreezeAccount;
pub const ThawAccount = freeze.ThawAccount;
pub const Revoke = revoke.Revoke;
pub const Approve = approve.Approve;
pub const ApproveChecked = approve.ApproveChecked;
