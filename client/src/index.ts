import 'dotenv/config';
import { Account, Cedra, CedraConfig, Ed25519PrivateKey, Network } from "@cedra-labs/ts-sdk";

// Configuration
const config = new CedraConfig({ network: Network.TESTNET });
const cedra = new Cedra(config);

// Contract constants
const MODULE_ADDRESS    = "0xeda50089567df24c65db892ef0d680946feb739a01085ececec1009c9eb796af"; // @peelswap
const MODULE_NAME       = "peelswap_fungible_asset";
const CEDRA_TYPE        = `0x1::cedra_coin::CedraCoin`;
const METADATA_ADDRESS  = `0xb8ec06c56ae7f89e8eb032b576f3c4b7688d166b137e7a92db5b20dc6a1e40c2`;
const ONE_CEDRA         = 100_000_000; // Octas
const ONE_PEEL          = 100_000_000; // decimals = 8

// Initialize accounts from environment variables
function initializeAccounts(): { admin: Account; user: Account } {
  const admin = Account.fromPrivateKey({
    'privateKey': new Ed25519PrivateKey(process.env.ADMIN_PRIVATE_KEY || '')
  });
  const user = Account.fromPrivateKey({
    'privateKey': new Ed25519PrivateKey(process.env.USER_PRIVATE_KEY || '')
  });
  
  console.log(`Admin: ${admin.accountAddress}`);
  console.log(`User: ${user.accountAddress}`);
  
  return { admin, user };
}

// Fund accounts with CEDRA tokens
async function fundAccounts(admin: Account, user: Account): Promise<void> {
  console.log('Funding accounts...');
  await cedra.faucet.fundAccount({ 
    accountAddress: admin.accountAddress, 
    amount: ONE_CEDRA 
  });
  await cedra.faucet.fundAccount({ 
    accountAddress: user.accountAddress, 
    amount: ONE_CEDRA 
  });
  console.log('Accounts funded successfully');
}

// Mint PEEL tokens
async function mint(signer: Account): Promise<string> {
  console.log('Minting PEEL tokens...');
  const mintTxn = await cedra.transaction.build.simple({
    sender: signer.accountAddress,
    data: {
      function: `${MODULE_ADDRESS}::${MODULE_NAME}::mint`,
      functionArguments: [],
    }
  });
  
  const { hash: mintHash } = await cedra.signAndSubmitTransaction({ 
    signer, 
    transaction: mintTxn 
  });
  await cedra.waitForTransaction({ transactionHash: mintHash });
  console.log(`Mint transaction hash: ${mintHash}`);
  
  return mintHash;
}

// Transfer PEEL tokens
async function transfer(
  sender: Account, 
  recipientAddress: string, 
  amount: number
): Promise<string> {
  console.log(`Transferring ${amount / ONE_PEEL} PEEL tokens...`);
  const transferTxn = await cedra.transaction.build.simple({
    sender: sender.accountAddress,
    data: {
      function: `${MODULE_ADDRESS}::${MODULE_NAME}::transfer`,
      functionArguments: [recipientAddress, amount],
    }
  });
  
  const { hash: transferHash } = await cedra.signAndSubmitTransaction({ 
    signer: sender, 
    transaction: transferTxn 
  });
  await cedra.waitForTransaction({ transactionHash: transferHash });
  console.log(`Transfer transaction hash: ${transferHash}`);
  
  return transferHash;
}

// Get metadata address
async function getMetadataAddress(): Promise<string> {
  const metadataAddress = await cedra.view({
    payload: {
      function: `${MODULE_ADDRESS}::${MODULE_NAME}::get_metadata`,
      typeArguments: [],
      functionArguments: [],
    }
  });
  
  const address = metadataAddress[0]?.toString() || '';
  console.log(`Metadata address: ${address}`);
  return address;
}

// Alternative: Get PeelswapFungibleAsset using direct object address
async function getPeelswapFungibleAsset(): Promise<{ admin: string; mintRate: number }> {
  try {
    
    console.log(`Reading resource directly from: ${METADATA_ADDRESS}`);
    
    const resource = await cedra.account.getAccountResource({
      accountAddress: METADATA_ADDRESS,
      resourceType: `${MODULE_ADDRESS}::${MODULE_NAME}::PeelswapFungibleAsset`
    });
    
    console.log('Direct resource data:', JSON.stringify(resource, null, 2));
    
    const admin = resource?.data?.admin || '';
    const mintRate = parseInt(resource?.data?.mint_rate || '0');
    
    return { admin, mintRate };
    
  } catch (error) {
    console.error('Error reading resource directly:', error);
    return { admin: '', mintRate: 0 };
  }
}

// Get CEDRA balance
async function getCedraBalance(accountAddress: string): Promise<number> {
  const balance = await cedra.account.getAccountCoinAmount({
    accountAddress,
    coinType: CEDRA_TYPE,
  });
  
  return balance;
}

// Get PEEL balance
async function getPeelBalance(accountAddress: string): Promise<number> {
  const balance = await cedra.account.getAccountCoinAmount({
    accountAddress,
    faMetadataAddress: METADATA_ADDRESS,
  });
  
  return balance;
}

// Display all balances
async function displayBalances(admin: Account, user: Account): Promise<void> {
  console.log('\n=== Account Balances ===');
  
  // CEDRA balances
  const adminCedraBalance = await getCedraBalance(admin.accountAddress.toString());
  const userCedraBalance = await getCedraBalance(user.accountAddress.toString());
  
  console.log(`Admin CEDRA balance: ${adminCedraBalance / ONE_CEDRA} CEDRA`);
  console.log(`User CEDRA balance: ${userCedraBalance / ONE_CEDRA} CEDRA`);
  
  // PEEL balances
  const adminPeelBalance = await getPeelBalance(admin.accountAddress.toString());
  const userPeelBalance = await getPeelBalance(user.accountAddress.toString());
  
  console.log(`Admin PEEL balance: ${adminPeelBalance / ONE_PEEL} PEEL`);
  console.log(`User PEEL balance: ${userPeelBalance / ONE_PEEL} PEEL`);
  console.log('========================\n');
}

// Set mint rate (admin function)
async function setMintRate(admin: Account, newRate: number): Promise<string> {
  console.log(`Setting mint rate to ${newRate}...`);
  const setRateTxn = await cedra.transaction.build.simple({
    sender: admin.accountAddress,
    data: {
      function: `${MODULE_ADDRESS}::${MODULE_NAME}::set_mint_rate`,
      functionArguments: [newRate],
    }
  });
  
  const { hash: hash } = await cedra.signAndSubmitTransaction({ 
    signer: admin, 
    transaction: setRateTxn 
  });
  await cedra.waitForTransaction({ transactionHash: hash });
  console.log(`Set mint rate transaction hash: ${hash}`);
  
  return hash;
}

// Main function
async function main() {
  try {
    // Initialize accounts
    const { admin, user } = initializeAccounts();
    
    // Try direct method first (using known object address)
    await getPeelswapFungibleAsset();
    
    // Try dynamic method (getting object address via view)
    // console.log('\n=== Trying Dynamic Method ===');
    // await getPeelswapFungibleAsset();
    
    // Display initial balances
    await displayBalances(admin, user);
    
    // Mint PEEL tokens
    // await mint(admin)

    // Transfer PEEL tokens (example)
    // await transferPeelTokens(user, admin.accountAddress.toString(), 123 * ONE_PEEL);
    
    // Display balances after transfer
    await displayBalances(admin, user);
    
  } catch (error) {
    console.error('Error in main function:', error);
  }
}

// Export functions for use in other modules
export {
  initializeAccounts,
  fundAccounts,
  mint,
  transfer,
  getMetadataAddress,
  getPeelswapFungibleAsset,
  getCedraBalance,
  getPeelBalance,
  displayBalances,
  setMintRate,
  MODULE_ADDRESS,
  MODULE_NAME,
  METADATA_ADDRESS,
  ONE_CEDRA,
  ONE_PEEL
};

// Run main function if this file is executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}