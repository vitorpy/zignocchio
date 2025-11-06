import {
  Connection,
  Keypair,
  PublicKey,
  Transaction,
  TransactionInstruction,
  sendAndConfirmTransaction,
  SystemProgram,
  LAMPORTS_PER_SOL,
} from '@solana/web3.js';
import {
  createMint,
  createAccount,
  mintTo,
  getAccount,
  TOKEN_PROGRAM_ID,
} from '@solana/spl-token';
import { execSync, spawn, ChildProcess } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

describe('Token Vault Program', () => {
  let validator: ChildProcess;
  let connection: Connection;
  let programId: PublicKey;
  let payer: Keypair;
  let mintAuthority: Keypair;
  let mint: PublicKey;
  let userTokenAccount: PublicKey;
  let vaultTokenAccount: PublicKey;

  // Instruction discriminators
  const DEPOSIT = 0;
  const WITHDRAW = 1;
  const INITIALIZE = 2;

  beforeAll(async () => {
    // Kill any existing test validator
    try {
      execSync('killall -9 solana-test-validator node jest', { stdio: 'ignore' });
    } catch (e) {
      // Ignore if no process found
    }

    // Wait a bit for cleanup
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Build the token-vault program
    console.log('Building token-vault program...');
    execSync('zig build -Dexample=token-vault', { stdio: 'inherit' });

    // Generate program keypair for deployment
    const programKeypair = Keypair.generate();
    programId = programKeypair.publicKey;
    console.log('Program ID:', programId.toBase58());

    // Write keypair to temporary file
    const programKeypairPath = path.join(__dirname, '..', 'test-program-keypair.json');
    fs.writeFileSync(
      programKeypairPath,
      JSON.stringify(Array.from(programKeypair.secretKey))
    );

    // Start test validator with program deployed
    const programPath = path.join(__dirname, '..', 'zig-out', 'lib', 'program_name.so');

    if (!fs.existsSync(programPath)) {
      throw new Error(`Program not found at ${programPath}. Run 'zig build' first.`);
    }

    console.log('Starting solana-test-validator...');
    validator = spawn('solana-test-validator', [
      '--reset',
      '--quiet',
      '--bpf-program',
      programKeypairPath,
      programPath,
    ], {
      detached: true,
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    validator.stderr?.on('data', (_data) => {
      // Suppressing validator stderr
    });

    validator.on('error', (err) => {
      throw new Error(`Failed to start validator: ${err}`);
    });

    validator.unref();

    // Wait for validator to be ready
    await new Promise(resolve => setTimeout(resolve, 5000));

    // Connect to test validator
    connection = new Connection('http://localhost:8899', 'confirmed');

    // Setup payer and mint authority
    payer = Keypair.generate();
    mintAuthority = Keypair.generate();

    // Airdrop SOL to payer
    const airdropSig = await connection.requestAirdrop(
      payer.publicKey,
      10 * LAMPORTS_PER_SOL
    );
    await connection.confirmTransaction(airdropSig);

    console.log('Payer funded:', payer.publicKey.toBase58());

    // Create mint
    mint = await createMint(
      connection,
      payer,
      mintAuthority.publicKey,
      null,
      9 // 9 decimals
    );
    console.log('Mint created:', mint.toBase58());

    // Create user token account
    userTokenAccount = await createAccount(
      connection,
      payer,
      mint,
      payer.publicKey
    );
    console.log('User token account:', userTokenAccount.toBase58());

    // Mint tokens to user
    await mintTo(
      connection,
      payer,
      mint,
      userTokenAccount,
      mintAuthority,
      1_000_000_000 // 1 token with 9 decimals
    );
    console.log('Minted 1 token to user');

    // Derive vault token account PDA
    const [vaultPda] = PublicKey.findProgramAddressSync(
      [Buffer.from('vault'), payer.publicKey.toBuffer()],
      programId
    );
    vaultTokenAccount = vaultPda;
    console.log('Vault token account PDA:', vaultTokenAccount.toBase58());

    // Initialize vault via program instruction (creates PDA via CPI)
    const RENT_SYSVAR = new PublicKey('SysvarRent111111111111111111111111111111111');
    const initVaultIx = new TransactionInstruction({
      keys: [
        { pubkey: vaultTokenAccount, isSigner: false, isWritable: true },
        { pubkey: mint, isSigner: false, isWritable: false },
        { pubkey: payer.publicKey, isSigner: true, isWritable: true },
        { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
        { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
        { pubkey: RENT_SYSVAR, isSigner: false, isWritable: false },
      ],
      programId,
      data: Buffer.from([INITIALIZE]),
    });

    const initTx = new Transaction().add(initVaultIx);
    await sendAndConfirmTransaction(connection, initTx, [payer]);

    console.log('Vault token account initialized');
  }, 60000);

  afterAll(async () => {
    // Kill the validator
    if (validator) {
      try {
        process.kill(-validator.pid!);
      } catch (e) {
        // Ignore
      }
    }

    // Clean up
    try {
      execSync('killall -9 solana-test-validator', { stdio: 'ignore' });
    } catch (e) {
      // Ignore
    }
  });

  /**
   * Helper: Create deposit instruction
   */
  function createDepositInstruction(
    userTokenAccount: PublicKey,
    vaultTokenAccount: PublicKey,
    owner: PublicKey,
    amount: bigint
  ): TransactionInstruction {
    const data = Buffer.alloc(9);
    data[0] = DEPOSIT;
    data.writeBigUInt64LE(amount, 1);

    return new TransactionInstruction({
      keys: [
        { pubkey: userTokenAccount, isSigner: false, isWritable: true },
        { pubkey: vaultTokenAccount, isSigner: false, isWritable: true },
        { pubkey: owner, isSigner: true, isWritable: false },
        { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
      ],
      programId,
      data,
    });
  }

  /**
   * Helper: Create withdraw instruction
   */
  function createWithdrawInstruction(
    vaultTokenAccount: PublicKey,
    userTokenAccount: PublicKey,
    owner: PublicKey
  ): TransactionInstruction {
    return new TransactionInstruction({
      keys: [
        { pubkey: vaultTokenAccount, isSigner: false, isWritable: true },
        { pubkey: userTokenAccount, isSigner: false, isWritable: true },
        { pubkey: owner, isSigner: true, isWritable: false },
        { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
      ],
      programId,
      data: Buffer.from([WITHDRAW]),
    });
  }

  describe('Deposit', () => {
    it('should deposit tokens into vault', async () => {
      console.log('\n=== Testing Deposit ===');

      // Check initial balances
      const userAccountBefore = await getAccount(connection, userTokenAccount);
      const vaultAccountBefore = await getAccount(connection, vaultTokenAccount);

      console.log('User balance before:', userAccountBefore.amount.toString());
      console.log('Vault balance before:', vaultAccountBefore.amount.toString());

      const depositAmount = BigInt(500_000_000); // 0.5 tokens

      // Create and send deposit instruction
      const depositIx = createDepositInstruction(
        userTokenAccount,
        vaultTokenAccount,
        payer.publicKey,
        depositAmount
      );
      const tx = new Transaction().add(depositIx);
      const sig = await sendAndConfirmTransaction(connection, tx, [payer]);
      console.log('Deposit signature:', sig);

      // Check balances after
      const userAccountAfter = await getAccount(connection, userTokenAccount);
      const vaultAccountAfter = await getAccount(connection, vaultTokenAccount);

      console.log('User balance after:', userAccountAfter.amount.toString());
      console.log('Vault balance after:', vaultAccountAfter.amount.toString());

      // Verify
      expect(userAccountAfter.amount).toBe(userAccountBefore.amount - depositAmount);
      expect(vaultAccountAfter.amount).toBe(vaultAccountBefore.amount + depositAmount);

      // Verify logs
      const txDetails = await connection.getTransaction(sig, {
        commitment: 'confirmed',
        maxSupportedTransactionVersion: 0,
      });
      const logs = txDetails?.meta?.logMessages || [];
      console.log('Deposit logs:', logs);

      const hasDepositLog = logs.some(log =>
        log.includes('Deposit: Starting') || log.includes('Deposit: Transfer completed')
      );
      expect(hasDepositLog).toBe(true);
    }, 30000);

    it('should fail to deposit zero amount', async () => {
      const depositIx = createDepositInstruction(
        userTokenAccount,
        vaultTokenAccount,
        payer.publicKey,
        BigInt(0)
      );
      const tx = new Transaction().add(depositIx);

      await expect(
        sendAndConfirmTransaction(connection, tx, [payer])
      ).rejects.toThrow();
    }, 30000);
  });

  describe('Withdraw', () => {
    it('should withdraw all tokens from vault', async () => {
      console.log('\n=== Testing Withdraw ===');

      // Check initial balances
      const userAccountBefore = await getAccount(connection, userTokenAccount);
      const vaultAccountBefore = await getAccount(connection, vaultTokenAccount);

      console.log('User balance before:', userAccountBefore.amount.toString());
      console.log('Vault balance before:', vaultAccountBefore.amount.toString());

      expect(vaultAccountBefore.amount).toBeGreaterThan(BigInt(0));

      // Create and send withdraw instruction
      const withdrawIx = createWithdrawInstruction(
        vaultTokenAccount,
        userTokenAccount,
        payer.publicKey
      );
      const tx = new Transaction().add(withdrawIx);
      const sig = await sendAndConfirmTransaction(connection, tx, [payer]);
      console.log('Withdraw signature:', sig);

      // Check balances after
      const userAccountAfter = await getAccount(connection, userTokenAccount);
      const vaultAccountAfter = await getAccount(connection, vaultTokenAccount);

      console.log('User balance after:', userAccountAfter.amount.toString());
      console.log('Vault balance after:', vaultAccountAfter.amount.toString());

      // Verify
      expect(vaultAccountAfter.amount).toBe(BigInt(0));
      expect(userAccountAfter.amount).toBe(
        userAccountBefore.amount + vaultAccountBefore.amount
      );

      // Verify logs
      const txDetails = await connection.getTransaction(sig, {
        commitment: 'confirmed',
        maxSupportedTransactionVersion: 0,
      });
      const logs = txDetails?.meta?.logMessages || [];
      console.log('Withdraw logs:', logs);

      const hasWithdrawLog = logs.some(log =>
        log.includes('Withdraw: Starting') || log.includes('Withdraw: Transfer completed')
      );
      expect(hasWithdrawLog).toBe(true);
    }, 30000);

    it('should fail to withdraw from empty vault', async () => {
      const withdrawIx = createWithdrawInstruction(
        vaultTokenAccount,
        userTokenAccount,
        payer.publicKey
      );
      const tx = new Transaction().add(withdrawIx);

      // Should fail because vault is now empty
      await expect(
        sendAndConfirmTransaction(connection, tx, [payer])
      ).rejects.toThrow();
    }, 30000);
  });

  describe('Full Cycle', () => {
    it('should complete a full deposit-withdraw cycle', async () => {
      // Create new user with token account
      const newUser = Keypair.generate();
      const airdropSig = await connection.requestAirdrop(
        newUser.publicKey,
        5 * LAMPORTS_PER_SOL
      );
      await connection.confirmTransaction(airdropSig);

      // Create token account for new user
      const newUserTokenAccount = await createAccount(
        connection,
        payer,
        mint,
        newUser.publicKey
      );

      // Mint tokens to new user
      await mintTo(
        connection,
        payer,
        mint,
        newUserTokenAccount,
        mintAuthority,
        1_000_000_000 // 1 token
      );

      // Derive vault token account PDA for new user
      const [newVaultPda] = PublicKey.findProgramAddressSync(
        [Buffer.from('vault'), newUser.publicKey.toBuffer()],
        programId
      );

      // Initialize vault via program instruction
      const RENT_SYSVAR = new PublicKey('SysvarRent111111111111111111111111111111111');
      const initVaultIx = new TransactionInstruction({
        keys: [
          { pubkey: newVaultPda, isSigner: false, isWritable: true },
          { pubkey: mint, isSigner: false, isWritable: false },
          { pubkey: newUser.publicKey, isSigner: true, isWritable: true },
          { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
          { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
          { pubkey: RENT_SYSVAR, isSigner: false, isWritable: false },
        ],
        programId,
        data: Buffer.from([INITIALIZE]),
      });

      const setupTx = new Transaction().add(initVaultIx);
      await sendAndConfirmTransaction(connection, setupTx, [newUser]);

      const initialBalance = (await getAccount(connection, newUserTokenAccount)).amount;
      console.log('Initial user token balance:', initialBalance.toString());

      const depositAmount = BigInt(600_000_000); // 0.6 tokens

      // Deposit
      const depositIx = createDepositInstruction(
        newUserTokenAccount,
        newVaultPda,
        newUser.publicKey,
        depositAmount
      );
      const depositTx = new Transaction().add(depositIx);
      await sendAndConfirmTransaction(connection, depositTx, [newUser]);

      const vaultBalance = (await getAccount(connection, newVaultPda)).amount;
      expect(vaultBalance).toBe(depositAmount);

      // Withdraw
      const withdrawIx = createWithdrawInstruction(
        newVaultPda,
        newUserTokenAccount,
        newUser.publicKey
      );
      const withdrawTx = new Transaction().add(withdrawIx);
      await sendAndConfirmTransaction(connection, withdrawTx, [newUser]);

      const finalVaultBalance = (await getAccount(connection, newVaultPda)).amount;
      expect(finalVaultBalance).toBe(BigInt(0));

      const finalBalance = (await getAccount(connection, newUserTokenAccount)).amount;
      console.log('Final user token balance:', finalBalance.toString());

      // User should have exact same token balance
      expect(finalBalance).toBe(initialBalance);
    }, 60000);
  });

  describe('Security', () => {
    it('should fail with wrong signer', async () => {
      const wrongUser = Keypair.generate();
      const airdropSig = await connection.requestAirdrop(
        wrongUser.publicKey,
        2 * LAMPORTS_PER_SOL
      );
      await connection.confirmTransaction(airdropSig);

      // Try to deposit from payer's account but sign with wrong user
      const depositIx = createDepositInstruction(
        userTokenAccount,
        vaultTokenAccount,
        payer.publicKey,
        BigInt(100_000_000)
      );
      const tx = new Transaction().add(depositIx);

      // Should fail because wrongUser is signing but payer.publicKey is in the instruction
      await expect(
        sendAndConfirmTransaction(connection, tx, [wrongUser])
      ).rejects.toThrow();
    }, 30000);

    it('should fail with invalid vault PDA', async () => {
      // Use a random vault address instead of the correct PDA
      const randomVault = Keypair.generate().publicKey;

      const depositIx = createDepositInstruction(
        userTokenAccount,
        randomVault,
        payer.publicKey,
        BigInt(100_000_000)
      );
      const tx = new Transaction().add(depositIx);

      await expect(
        sendAndConfirmTransaction(connection, tx, [payer])
      ).rejects.toThrow();
    }, 30000);
  });
});
