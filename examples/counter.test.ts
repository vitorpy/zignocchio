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

describe('Counter Program', () => {
  let validator: ChildProcess;
  let connection: Connection;
  let programId: PublicKey;
  let payer: Keypair;
  let counterAccount: Keypair;

  beforeAll(async () => {
    // Kill any existing test validator
    try {
      execSync('pkill -f solana-test-validator', { stdio: 'ignore' });
    } catch (e) {
      // Ignore if no process found
    }

    // Wait a bit for cleanup
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Build the counter program
    console.log('Building counter program...');
    execSync('zig build -Dexample=counter', { stdio: 'inherit' });

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

    // Create counter account
    counterAccount = Keypair.generate();
    const space = 8; // u64 counter
    const lamports = await connection.getMinimumBalanceForRentExemption(space);

    const createAccountIx = SystemProgram.createAccount({
      fromPubkey: payer.publicKey,
      newAccountPubkey: counterAccount.publicKey,
      lamports,
      space,
      programId,
    });

    const tx = new Transaction().add(createAccountIx);
    await sendAndConfirmTransaction(connection, tx, [payer, counterAccount]);

    console.log('Counter account created:', counterAccount.publicKey.toBase58());
  }, 60000); // 60 second timeout

  afterAll(async () => {
    // Stop solana-test-validator
    try {
      execSync('pkill -f solana-test-validator');
    } catch (e) {
      // Ignore errors
    }
  });

  async function getCounterValue(): Promise<number> {
    const accountInfo = await connection.getAccountInfo(counterAccount.publicKey);
    if (!accountInfo) throw new Error('Counter account not found');
    return Number(accountInfo.data.readBigUInt64LE(0));
  }

  it('should increment counter (default operation)', async () => {
    const instruction = new TransactionInstruction({
      keys: [
        { pubkey: counterAccount.publicKey, isSigner: false, isWritable: true },
      ],
      programId,
      data: Buffer.alloc(0), // Empty = default increment
    });

    const transaction = new Transaction().add(instruction);
    await sendAndConfirmTransaction(connection, transaction, [payer]);

    const value = await getCounterValue();
    expect(value).toBe(1);
  });

  it('should increment counter explicitly (operation 0)', async () => {
    const instruction = new TransactionInstruction({
      keys: [
        { pubkey: counterAccount.publicKey, isSigner: false, isWritable: true },
      ],
      programId,
      data: Buffer.from([0]), // Operation 0 = increment
    });

    const transaction = new Transaction().add(instruction);
    await sendAndConfirmTransaction(connection, transaction, [payer]);

    const value = await getCounterValue();
    expect(value).toBe(2); // Was 1, now 2
  });

  it('should decrement counter (operation 1)', async () => {
    const instruction = new TransactionInstruction({
      keys: [
        { pubkey: counterAccount.publicKey, isSigner: false, isWritable: true },
      ],
      programId,
      data: Buffer.from([1]), // Operation 1 = decrement
    });

    const transaction = new Transaction().add(instruction);
    await sendAndConfirmTransaction(connection, transaction, [payer]);

    const value = await getCounterValue();
    expect(value).toBe(1); // Was 2, now 1
  });

  it('should reset counter (operation 2)', async () => {
    const instruction = new TransactionInstruction({
      keys: [
        { pubkey: counterAccount.publicKey, isSigner: false, isWritable: true },
      ],
      programId,
      data: Buffer.from([2]), // Operation 2 = reset
    });

    const transaction = new Transaction().add(instruction);
    await sendAndConfirmTransaction(connection, transaction, [payer]);

    const value = await getCounterValue();
    expect(value).toBe(0);
  });

  it('should log counter operations', async () => {
    // Increment
    const instruction = new TransactionInstruction({
      keys: [
        { pubkey: counterAccount.publicKey, isSigner: false, isWritable: true },
      ],
      programId,
      data: Buffer.from([0]),
    });

    const transaction = new Transaction().add(instruction);
    const signature = await sendAndConfirmTransaction(connection, transaction, [payer]);

    const txDetails = await connection.getTransaction(signature, {
      commitment: 'confirmed',
      maxSupportedTransactionVersion: 0,
    });

    const logs = txDetails?.meta?.logMessages || [];
    console.log('Counter logs:', logs);

    // Should have logged the counter operation
    const hasCounterLog = logs.some(log =>
      log.includes('Counter program: starting') ||
      log.includes('Incremented counter')
    );

    expect(hasCounterLog).toBe(true);
  });

  it('should fail with unknown operation', async () => {
    const instruction = new TransactionInstruction({
      keys: [
        { pubkey: counterAccount.publicKey, isSigner: false, isWritable: true },
      ],
      programId,
      data: Buffer.from([99]), // Invalid operation
    });

    const transaction = new Transaction().add(instruction);

    // Should fail
    await expect(
      sendAndConfirmTransaction(connection, transaction, [payer])
    ).rejects.toThrow();
  });
});
