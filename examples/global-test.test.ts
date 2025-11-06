/**
 * Global Constant Test - Minimal reproduction for zignocchio-7acb
 *
 * Tests whether global constants cause BPF runtime crashes.
 */

import {
  Connection,
  Keypair,
  LAMPORTS_PER_SOL,
  Transaction,
  TransactionInstruction,
  sendAndConfirmTransaction,
} from '@solana/web3.js';
import { execSync, spawn, ChildProcess } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';

describe('Global Constant Test', () => {
  let connection: Connection;
  let payer: Keypair;
  let programId: any;
  let validator: ChildProcess;

  beforeAll(async () => {
    // Kill any existing test validator
    try {
      execSync('killall -9 solana-test-validator node jest', { stdio: 'ignore' });
    } catch (e) {
      // Ignore if no process found
    }

    await new Promise(resolve => setTimeout(resolve, 2000));

    // Build the global-test program
    console.log('Building global-test program...');
    execSync('zig build -Dexample=global-test', { stdio: 'inherit' });

    // Generate program keypair
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
      throw new Error(`Program not found at ${programPath}`);
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

    // Setup payer
    payer = Keypair.generate();

    // Airdrop SOL to payer
    const airdropSig = await connection.requestAirdrop(
      payer.publicKey,
      10 * LAMPORTS_PER_SOL
    );
    await connection.confirmTransaction(airdropSig);

    console.log('Payer funded:', payer.publicKey.toBase58());
  }, 60000);

  afterAll(async () => {
    if (connection) {
      try {
        const conn = connection as any;
        if (conn._rpcWebSocket) {
          conn._rpcWebSocket.close();
        }
      } catch (e) {
        // Ignore
      }
    }

    if (validator) {
      try {
        process.kill(-validator.pid!);
      } catch (e) {
        // Ignore
      }
    }

    await new Promise(resolve => setTimeout(resolve, 1000));
  }, 30000);

  it('Test 0: Baseline - no global reference', async () => {
    console.log('\n=== Test 0: Baseline ===');

    const ix = new TransactionInstruction({
      keys: [],
      programId,
      data: Buffer.from([0]), // Test type 0
    });

    const tx = new Transaction().add(ix);
    const sig = await sendAndConfirmTransaction(connection, tx, [payer]);
    console.log('Test 0 transaction:', sig);

    expect(sig).toBeTruthy();
  }, 30000);

  it('Test 1: Reference global constant', async () => {
    console.log('\n=== Test 1: Global Constant Reference ===');

    const ix = new TransactionInstruction({
      keys: [],
      programId,
      data: Buffer.from([1]), // Test type 1
    });

    const tx = new Transaction().add(ix);
    const sig = await sendAndConfirmTransaction(connection, tx, [payer]);
    console.log('Test 1 transaction:', sig);

    expect(sig).toBeTruthy();
  }, 30000);

  it('Test 2: Inline function workaround', async () => {
    console.log('\n=== Test 2: Inline Function ===');

    const ix = new TransactionInstruction({
      keys: [],
      programId,
      data: Buffer.from([2]), // Test type 2
    });

    const tx = new Transaction().add(ix);
    const sig = await sendAndConfirmTransaction(connection, tx, [payer]);
    console.log('Test 2 transaction:', sig);

    expect(sig).toBeTruthy();
  }, 30000);

  it('Test 3: TOKEN_PROGRAM_ID constant specifically', async () => {
    console.log('\n=== Test 3: TOKEN_PROGRAM_ID ===');

    const ix = new TransactionInstruction({
      keys: [],
      programId,
      data: Buffer.from([3]), // Test type 3
    });

    const tx = new Transaction().add(ix);
    const sig = await sendAndConfirmTransaction(connection, tx, [payer]);
    console.log('Test 3 transaction:', sig);

    expect(sig).toBeTruthy();
  }, 30000);

  it('Test 4: Cross-module TOKEN_PROGRAM_ID reference', async () => {
    console.log('\n=== Test 4: Cross-module Reference ===');

    const ix = new TransactionInstruction({
      keys: [],
      programId,
      data: Buffer.from([4]), // Test type 4
    });

    const tx = new Transaction().add(ix);
    const sig = await sendAndConfirmTransaction(connection, tx, [payer]);
    console.log('Test 4 transaction:', sig);

    expect(sig).toBeTruthy();
  }, 30000);

  it('Test 5: Helper function with TOKEN_PROGRAM_ID (SDK pattern)', async () => {
    console.log('\n=== Test 5: Helper Function (SDK Pattern) ===');

    const ix = new TransactionInstruction({
      keys: [],
      programId,
      data: Buffer.from([5]), // Test type 5
    });

    const tx = new Transaction().add(ix);
    const sig = await sendAndConfirmTransaction(connection, tx, [payer]);
    console.log('Test 5 transaction:', sig);

    expect(sig).toBeTruthy();
  }, 30000);
});
