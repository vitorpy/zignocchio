import {
  Connection,
  Keypair,
  PublicKey,
  Transaction,
  TransactionInstruction,
  sendAndConfirmTransaction,
} from '@solana/web3.js';
import { execSync, spawn, ChildProcess } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

describe('Hello World Program', () => {
  let validator: ChildProcess;
  let connection: Connection;
  let programId: PublicKey;
  let payer: Keypair;

  beforeAll(async () => {
    // Kill any existing test validator
    try {
      execSync('pkill -f solana-test-validator', { stdio: 'ignore' });
    } catch (e) {
      // Ignore if no process found
    }

    // Wait a bit for cleanup
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Build the hello program
    console.log('Building hello program...');
    execSync('zig build -Dexample=hello', { stdio: 'inherit' });

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
  }, 60000); // 60 second timeout

  afterAll(async () => {
    // Stop solana-test-validator
    try {
      execSync('pkill -f solana-test-validator');
    } catch (e) {
      // Ignore errors
    }
  });

  it('should execute and log "Hello from Zignocchio!"', async () => {
    // Create instruction - empty data
    const instruction = new TransactionInstruction({
      keys: [],
      programId,
      data: Buffer.alloc(0),
    });

    // Create and send transaction
    const transaction = new Transaction().add(instruction);

    console.log('Sending transaction...');
    const signature = await sendAndConfirmTransaction(
      connection,
      transaction,
      [payer],
      { commitment: 'confirmed' }
    );

    console.log('Transaction signature:', signature);

    // Fetch transaction logs
    const txDetails = await connection.getTransaction(signature, {
      commitment: 'confirmed',
      maxSupportedTransactionVersion: 0,
    });

    expect(txDetails).not.toBeNull();
    expect(txDetails?.meta?.logMessages).toBeDefined();

    const logs = txDetails?.meta?.logMessages || [];
    console.log('Transaction logs:', logs);

    // Check for "Hello from Zignocchio!" in logs
    const hasMessage = logs.some(log =>
      log.includes('Hello from Zignocchio!')
    );

    expect(hasMessage).toBe(true);
  });

  it('should succeed with no errors', async () => {
    const instruction = new TransactionInstruction({
      keys: [],
      programId,
      data: Buffer.alloc(0),
    });

    const transaction = new Transaction().add(instruction);
    const signature = await sendAndConfirmTransaction(
      connection,
      transaction,
      [payer],
      { commitment: 'confirmed' }
    );

    const txDetails = await connection.getTransaction(signature, {
      commitment: 'confirmed',
      maxSupportedTransactionVersion: 0,
    });

    // Should not have any errors
    expect(txDetails?.meta?.err).toBeNull();
  });
});
