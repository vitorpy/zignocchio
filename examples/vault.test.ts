import {
  Connection,
  Keypair,
  PublicKey,
  Transaction,
  TransactionInstruction,
  sendAndConfirmTransaction,
  SystemProgram,
} from '@solana/web3.js';
import { execSync, spawn, ChildProcess } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

describe('Vault Program', () => {
  let validator: ChildProcess;
  let connection: Connection;
  let programId: PublicKey;
  let payer: Keypair;
  let user: Keypair;

  // Instruction discriminators
  const DEPOSIT = 0;
  const WITHDRAW = 1;

  beforeAll(async () => {
    // Kill any existing test validator
    try {
      execSync('pkill -f solana-test-validator', { stdio: 'ignore' });
    } catch (e) {
      // Ignore if no process found
    }

    // Wait a bit for cleanup
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Build the vault program
    console.log('Building vault program...');
    execSync('zig build -Dexample=vault', { stdio: 'inherit' });

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

    // Setup payer account
    payer = Keypair.generate();

    // Airdrop SOL to payer
    const airdropSig = await connection.requestAirdrop(
      payer.publicKey,
      2_000_000_000 // 2 SOL
    );
    await connection.confirmTransaction(airdropSig);

    console.log('Payer funded:', payer.publicKey.toBase58());

    // Verify program is available and executable
    let programReady = false;
    for (let i = 0; i < 10; i++) {
      const programAccount = await connection.getAccountInfo(programId);
      if (programAccount && programAccount.executable) {
        programReady = true;
        console.log('Program deployed successfully!');
        break;
      }
      await new Promise(resolve => setTimeout(resolve, 500));
    }

    if (!programReady) {
      throw new Error('Program not executable');
    }

    // Create user account
    user = Keypair.generate();
    const userAirdropSig = await connection.requestAirdrop(
      user.publicKey,
      1_000_000_000 // 1 SOL
    );
    await connection.confirmTransaction(userAirdropSig);
    console.log('User funded:', user.publicKey.toBase58());

  }, 60000); // 60 second timeout

  afterAll(async () => {
    // Close the connection to prevent hanging
    if (connection) {
      try {
        // Close the internal WebSocket to prevent Jest from hanging
        const conn = connection as any;
        if (conn._rpcWebSocket) {
          conn._rpcWebSocket.close();
        }
      } catch (e) {
        // Ignore errors during cleanup
      }
    }

    // Stop solana-test-validator
    try {
      execSync('pkill -f solana-test-validator');
    } catch (e) {
      // Ignore errors
    }

    // Give it a moment to clean up
    await new Promise(resolve => setTimeout(resolve, 100));
  });

  /**
   * Find the PDA vault address for a user
   */
  function findVaultPDA(userPubkey: PublicKey): PublicKey {
    const [pda] = PublicKey.findProgramAddressSync(
      [Buffer.from('vault'), userPubkey.toBuffer()],
      programId
    );
    return pda;
  }

  /**
   * Get vault balance
   */
  async function getVaultBalance(vaultPubkey: PublicKey): Promise<number> {
    const accountInfo = await connection.getAccountInfo(vaultPubkey);
    return accountInfo ? accountInfo.lamports : 0;
  }

  /**
   * Create deposit instruction
   */
  function createDepositInstruction(
    owner: PublicKey,
    vault: PublicKey,
    amount: number
  ): TransactionInstruction {
    // Instruction data: [discriminator: u8, amount: u64 LE]
    const data = Buffer.alloc(9);
    data.writeUInt8(DEPOSIT, 0);
    data.writeBigUInt64LE(BigInt(amount), 1);

    return new TransactionInstruction({
      keys: [
        { pubkey: owner, isSigner: true, isWritable: true },
        { pubkey: vault, isSigner: false, isWritable: true },
        { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
      ],
      programId,
      data,
    });
  }

  /**
   * Create withdraw instruction
   */
  function createWithdrawInstruction(
    owner: PublicKey,
    vault: PublicKey
  ): TransactionInstruction {
    // Instruction data: [discriminator: u8]
    const data = Buffer.from([WITHDRAW]);

    return new TransactionInstruction({
      keys: [
        { pubkey: owner, isSigner: true, isWritable: true },
        { pubkey: vault, isSigner: false, isWritable: true },
        { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
      ],
      programId,
      data,
    });
  }

  describe('Deposit', () => {
    it('should deposit lamports into vault', async () => {
      const vault = findVaultPDA(user.publicKey);
      const depositAmount = 100_000_000; // 0.1 SOL

      console.log('Vault PDA:', vault.toBase58());

      const userBalanceBefore = await connection.getBalance(user.publicKey);
      console.log('User balance before:', userBalanceBefore);

      const instruction = createDepositInstruction(user.publicKey, vault, depositAmount);
      const transaction = new Transaction().add(instruction);

      const signature = await sendAndConfirmTransaction(connection, transaction, [user]);
      console.log('Deposit signature:', signature);

      // Check vault balance
      const vaultBalance = await getVaultBalance(vault);
      expect(vaultBalance).toBe(depositAmount);

      // Check user balance decreased (minus rent + fees)
      const userBalanceAfter = await connection.getBalance(user.publicKey);
      expect(userBalanceAfter).toBeLessThanOrEqual(userBalanceBefore - depositAmount);

      // Verify logs
      const txDetails = await connection.getTransaction(signature, {
        commitment: 'confirmed',
        maxSupportedTransactionVersion: 0,
      });
      const logs = txDetails?.meta?.logMessages || [];
      console.log('Deposit logs:', logs);

      const hasDepositLog = logs.some(log =>
        log.includes('Deposit: Starting') || log.includes('Deposit: Transfer completed')
      );
      expect(hasDepositLog).toBe(true);
    });

    it('should fail to deposit zero amount', async () => {
      const vault = findVaultPDA(user.publicKey);

      const instruction = createDepositInstruction(user.publicKey, vault, 0);
      const transaction = new Transaction().add(instruction);

      await expect(
        sendAndConfirmTransaction(connection, transaction, [user])
      ).rejects.toThrow();
    });

    it('should fail to deposit into already-filled vault', async () => {
      const vault = findVaultPDA(user.publicKey);
      const depositAmount = 50_000_000; // 0.05 SOL

      const instruction = createDepositInstruction(user.publicKey, vault, depositAmount);
      const transaction = new Transaction().add(instruction);

      // Should fail because vault already has funds from previous test
      await expect(
        sendAndConfirmTransaction(connection, transaction, [user])
      ).rejects.toThrow();
    });
  });

  describe('Withdraw', () => {
    it('should withdraw all lamports from vault', async () => {
      const vault = findVaultPDA(user.publicKey);

      const vaultBalanceBefore = await getVaultBalance(vault);
      expect(vaultBalanceBefore).toBeGreaterThan(0); // Should have funds from deposit test

      const userBalanceBefore = await connection.getBalance(user.publicKey);
      console.log('User balance before withdraw:', userBalanceBefore);
      console.log('Vault balance before withdraw:', vaultBalanceBefore);

      const instruction = createWithdrawInstruction(user.publicKey, vault);
      const transaction = new Transaction().add(instruction);

      const signature = await sendAndConfirmTransaction(connection, transaction, [user]);
      console.log('Withdraw signature:', signature);

      // Check vault is empty
      const vaultBalanceAfter = await getVaultBalance(vault);
      expect(vaultBalanceAfter).toBe(0);

      // Check user received funds
      const userBalanceAfter = await connection.getBalance(user.publicKey);
      expect(userBalanceAfter).toBeGreaterThan(userBalanceBefore);

      // Verify logs
      const txDetails = await connection.getTransaction(signature, {
        commitment: 'confirmed',
        maxSupportedTransactionVersion: 0,
      });
      const logs = txDetails?.meta?.logMessages || [];
      console.log('Withdraw logs:', logs);

      const hasWithdrawLog = logs.some(log =>
        log.includes('Withdraw: Starting') || log.includes('Withdraw: Transfer completed')
      );
      expect(hasWithdrawLog).toBe(true);
    });

    it('should fail to withdraw from empty vault', async () => {
      const vault = findVaultPDA(user.publicKey);

      const instruction = createWithdrawInstruction(user.publicKey, vault);
      const transaction = new Transaction().add(instruction);

      // Should fail because vault is now empty
      await expect(
        sendAndConfirmTransaction(connection, transaction, [user])
      ).rejects.toThrow();
    });
  });

  describe('Full Cycle', () => {
    it('should complete a full deposit-withdraw cycle', async () => {
      // Create a new user for this test
      const newUser = Keypair.generate();
      const airdropSig = await connection.requestAirdrop(
        newUser.publicKey,
        1_000_000_000 // 1 SOL
      );
      await connection.confirmTransaction(airdropSig);

      const vault = findVaultPDA(newUser.publicKey);
      const depositAmount = 200_000_000; // 0.2 SOL

      const initialBalance = await connection.getBalance(newUser.publicKey);
      console.log('Initial balance:', initialBalance);

      // Deposit
      const depositIx = createDepositInstruction(newUser.publicKey, vault, depositAmount);
      const depositTx = new Transaction().add(depositIx);
      await sendAndConfirmTransaction(connection, depositTx, [newUser]);

      const vaultBalance = await getVaultBalance(vault);
      expect(vaultBalance).toBe(depositAmount);

      // Withdraw
      const withdrawIx = createWithdrawInstruction(newUser.publicKey, vault);
      const withdrawTx = new Transaction().add(withdrawIx);
      await sendAndConfirmTransaction(connection, withdrawTx, [newUser]);

      const finalVaultBalance = await getVaultBalance(vault);
      expect(finalVaultBalance).toBe(0);

      const finalBalance = await connection.getBalance(newUser.publicKey);
      console.log('Final balance:', finalBalance);

      // User should have nearly the same balance (minus transaction fees)
      const netLoss = initialBalance - finalBalance;
      console.log('Net loss (fees):', netLoss);
      expect(netLoss).toBeLessThanOrEqual(10_000); // Less than or equal to 0.00001 SOL in fees
    });
  });

  describe('Security', () => {
    it('should fail with wrong signer', async () => {
      const wrongUser = Keypair.generate();
      const airdropSig = await connection.requestAirdrop(
        wrongUser.publicKey,
        1_000_000_000
      );
      await connection.confirmTransaction(airdropSig);

      const vault = findVaultPDA(user.publicKey);

      // Try to deposit to user's vault but sign with wrong user
      const instruction = createDepositInstruction(user.publicKey, vault, 100_000_000);
      const transaction = new Transaction().add(instruction);

      // Should fail because wrongUser is signing but user.publicKey is in the instruction
      await expect(
        sendAndConfirmTransaction(connection, transaction, [wrongUser])
      ).rejects.toThrow();
    });

    it('should fail with invalid vault PDA', async () => {
      // Use a random vault address instead of the correct PDA
      const randomVault = Keypair.generate().publicKey;
      const depositAmount = 100_000_000;

      const instruction = createDepositInstruction(user.publicKey, randomVault, depositAmount);
      const transaction = new Transaction().add(instruction);

      await expect(
        sendAndConfirmTransaction(connection, transaction, [user])
      ).rejects.toThrow();
    });
  });
});
