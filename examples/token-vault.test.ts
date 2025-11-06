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

    // Create vault token account
    const createVaultAccountIx = SystemProgram.createAccount({
      fromPubkey: payer.publicKey,
      newAccountPubkey: vaultTokenAccount,
      lamports: await connection.getMinimumBalanceForRentExemption(165),
      space: 165, // TokenAccount size
      programId: TOKEN_PROGRAM_ID,
    });

    // Initialize vault token account
    const initializeAccountData = Buffer.alloc(34);
    initializeAccountData[0] = 18; // InitializeAccount3 discriminator
    mint.toBuffer().copy(initializeAccountData, 1); // owner (the PDA itself)
    vaultTokenAccount.toBuffer().copy(initializeAccountData, 33);

    const initVaultAccountIx = new TransactionInstruction({
      keys: [
        { pubkey: vaultTokenAccount, isSigner: false, isWritable: true },
        { pubkey: mint, isSigner: false, isWritable: false },
      ],
      programId: TOKEN_PROGRAM_ID,
      data: Buffer.concat([
        Buffer.from([18]), // InitializeAccount3
        vaultTokenAccount.toBuffer(), // owner = vault PDA
      ]),
    });

    const tx = new Transaction().add(createVaultAccountIx, initVaultAccountIx);
    await sendAndConfirmTransaction(connection, tx, [payer]);

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

  test('deposit tokens into vault', async () => {
    console.log('\n=== Testing Deposit ===');

    // Check initial balances
    const userAccountBefore = await getAccount(connection, userTokenAccount);
    const vaultAccountBefore = await getAccount(connection, vaultTokenAccount);

    console.log('User balance before:', userAccountBefore.amount.toString());
    console.log('Vault balance before:', vaultAccountBefore.amount.toString());

    // Create deposit instruction
    const depositAmount = BigInt(500_000_000); // 0.5 tokens
    const depositData = Buffer.alloc(9);
    depositData[0] = DEPOSIT;
    depositData.writeBigUInt64LE(depositAmount, 1);

    const depositIx = new TransactionInstruction({
      keys: [
        { pubkey: userTokenAccount, isSigner: false, isWritable: true },
        { pubkey: vaultTokenAccount, isSigner: false, isWritable: true },
        { pubkey: payer.publicKey, isSigner: true, isWritable: false },
        { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
      ],
      programId,
      data: depositData,
    });

    // Send transaction
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
  }, 30000);

  test('withdraw tokens from vault', async () => {
    console.log('\n=== Testing Withdraw ===');

    // Check initial balances
    const userAccountBefore = await getAccount(connection, userTokenAccount);
    const vaultAccountBefore = await getAccount(connection, vaultTokenAccount);

    console.log('User balance before:', userAccountBefore.amount.toString());
    console.log('Vault balance before:', vaultAccountBefore.amount.toString());

    expect(vaultAccountBefore.amount).toBeGreaterThan(BigInt(0));

    // Create withdraw instruction
    const withdrawData = Buffer.from([WITHDRAW]);

    const withdrawIx = new TransactionInstruction({
      keys: [
        { pubkey: vaultTokenAccount, isSigner: false, isWritable: true },
        { pubkey: userTokenAccount, isSigner: false, isWritable: true },
        { pubkey: payer.publicKey, isSigner: true, isWritable: false },
        { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
      ],
      programId,
      data: withdrawData,
    });

    // Send transaction
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
  }, 30000);
});
