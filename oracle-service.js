
require('dotenv').config();
const { ethers } = require('ethers');


const CONFIG = {
  RPC_URL: process.env.BASE_SEPOLIA_RPC_URL || 'https://sepolia.base.org',
  PRIVATE_KEY: process.env.PRIVATE_KEY,
  MANUAL_ADAPTER_ADDRESS: '0xbBD700ca8Fc326c90BA90A028fC1C7b36b0e9D7B',
  NVDA_FEED_ID: '0xd7f402a699378a97cf4b1f46fb772a465535d2fead1457bcb27b58312638e264',
  UPDATE_INTERVAL: 5 * 60 * 1000, // 5 minutes
  YAHOO_API_URL: 'https://query1.finance.yahoo.com/v8/finance/chart/NVDA',
};


const ADAPTER_ABI = [
  'function updatePrice(bytes32 feedId, uint256 price) external',
  'function prices(bytes32) external view returns (uint256 price, uint256 timestamp, bool exists)'
];

// Setup provider and wallet
const provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
const wallet = new ethers.Wallet(CONFIG.PRIVATE_KEY, provider);
const adapter = new ethers.Contract(CONFIG.MANUAL_ADAPTER_ADDRESS, ADAPTER_ABI, wallet);

// Statistics
let stats = {
  successfulUpdates: 0,
  failedUpdates: 0,
  lastPrice: null,
  lastUpdateTime: null,
  startTime: new Date(),
};

/**
 * Fetch current NVIDIA stock price from Yahoo Finance
 */
async function fetchNVIDIAPrice() {
  try {
    const response = await fetch(CONFIG.YAHOO_API_URL);
    
    if (!response.ok) {
      throw new Error(`Yahoo Finance API returned status ${response.status}`);
    }
    
    const data = await response.json();
    
    // Extract the current market price
    const result = data.chart.result[0];
    const price = result.meta.regularMarketPrice;
    
    if (!price || price <= 0) {
      throw new Error('Invalid price returned from API');
    }
    
    return price;
  } catch (error) {
    console.error('Error fetching price from Yahoo Finance:', error.message);
    throw error;
  }
}

/**
 * Update the price on-chain
 */
async function updatePriceOnChain(price) {
  try {
    // Convert price to 8 decimals (e.g., $145.67 -> 14567000000)
    const priceScaled = Math.floor(price * 1e8);
    
    console.log(`Sending transaction to update price to $${price.toFixed(2)} (${priceScaled})...`);
    
    const tx = await adapter.updatePrice(CONFIG.NVDA_FEED_ID, priceScaled);
    
    console.log(`Transaction sent: ${tx.hash}`);
    console.log(`   Waiting for confirmation...`);
    
    const receipt = await tx.wait();
    
    console.log(`Price updated successfully!`);
    console.log(`   Block: ${receipt.blockNumber}`);
    console.log(`   Gas used: ${receipt.gasUsed.toString()}`);
    
    return true;
  } catch (error) {
    console.error('Error updating price on-chain:', error.message);
    if (error.reason) console.error('   Reason:', error.reason);
    throw error;
  }
}

/**
 * Get current on-chain price
 */
async function getCurrentOnChainPrice() {
  try {
    const [price, timestamp, exists] = await adapter.prices(CONFIG.NVDA_FEED_ID);
    
    if (!exists) {
      return { price: null, timestamp: null };
    }
    
    return {
      price: Number(price) / 1e8,
      timestamp: new Date(Number(timestamp) * 1000),
    };
  } catch (error) {
    console.error('Error reading on-chain price:', error.message);
    return { price: null, timestamp: null };
  }
}

/**
 * Main update cycle
 */
async function updateCycle() {
  console.log('\n' + '='.repeat(80));
  console.log(`Update Cycle - ${new Date().toLocaleString()}`);
  console.log('='.repeat(80));
  
  try {
    console.log('Fetching NVIDIA price from Yahoo Finance...');
    const marketPrice = await fetchNVIDIAPrice();
    console.log(`Current market price: $${marketPrice.toFixed(2)}`);
    
    console.log('\nChecking current on-chain price...');
    const onChainData = await getCurrentOnChainPrice();
    
    if (onChainData.price !== null) {
      console.log(`   On-chain price: $${onChainData.price.toFixed(2)}`);
      console.log(`   Last update: ${onChainData.timestamp.toLocaleString()}`);
      
      const priceDiff = Math.abs(marketPrice - onChainData.price);
      const priceDiffPercent = (priceDiff / onChainData.price) * 100;
      console.log(`   Difference: $${priceDiff.toFixed(2)} (${priceDiffPercent.toFixed(2)}%)`);
    } else {
      console.log(`   No price set on-chain yet (first update)`);
    }
    
    console.log('\nUpdating price on-chain...');
    await updatePriceOnChain(marketPrice);
    
    // Update stats
    stats.successfulUpdates++;
    stats.lastPrice = marketPrice;
    stats.lastUpdateTime = new Date();
    
    // Print stats
    printStats();
    
  } catch (error) {
    stats.failedUpdates++;
    console.error('\nUpdate cycle failed:', error.message);
    printStats();
  }
}

/**
 * Print service statistics
 */
function printStats() {
  const uptime = Math.floor((new Date() - stats.startTime) / 1000);
  const hours = Math.floor(uptime / 3600);
  const minutes = Math.floor((uptime % 3600) / 60);
  const seconds = uptime % 60;
  
  console.log('\n' + '─'.repeat(80));
  console.log('STATISTICS');
  console.log('─'.repeat(80));
  console.log(`   Successful updates: ${stats.successfulUpdates}`);
  console.log(`   Failed updates: ${stats.failedUpdates}`);
  console.log(`   Last price: ${stats.lastPrice ? '$' + stats.lastPrice.toFixed(2) : 'N/A'}`);
  console.log(`   Last update: ${stats.lastUpdateTime ? stats.lastUpdateTime.toLocaleString() : 'N/A'}`);
  console.log(`   Uptime: ${hours}h ${minutes}m ${seconds}s`);
  console.log('─'.repeat(80));
}

/**
 * Start the oracle service
 */
async function start() {
  console.log('\n' + '█'.repeat(80));
  console.log('  NVIDIA PRICE ORACLE SERVICE');
  console.log('█'.repeat(80));
  console.log('\nConfiguration:');
  console.log(`  RPC URL: ${CONFIG.RPC_URL}`);
  console.log(`  ManualPriceAdapter: ${CONFIG.MANUAL_ADAPTER_ADDRESS}`);
  console.log(`  NVDA Feed ID: ${CONFIG.NVDA_FEED_ID}`);
  console.log(`  Update Interval: ${CONFIG.UPDATE_INTERVAL / 1000} seconds (${CONFIG.UPDATE_INTERVAL / 60000} minutes)`);
  console.log(`  Wallet Address: ${wallet.address}`);
  
  // Check wallet balance
  try {
    const balance = await provider.getBalance(wallet.address);
    console.log(`  Wallet Balance: ${ethers.formatEther(balance)} ETH`);
    
    if (balance === 0n) {
      console.warn('\nWARNING: Wallet has zero balance. Please add ETH to continue.');
    }
  } catch (error) {
    console.error('Could not check wallet balance:', error.message);
  }
  
  console.log('\nService started successfully!');
  console.log(`First update will run immediately, then every ${CONFIG.UPDATE_INTERVAL / 60000} minutes.\n`);
  
  // Run first update immediately
  await updateCycle();
  
  // Schedule periodic updates
  setInterval(updateCycle, CONFIG.UPDATE_INTERVAL);
  
  console.log(`\nNext update scheduled for: ${new Date(Date.now() + CONFIG.UPDATE_INTERVAL).toLocaleString()}`);
  console.log('   Press Ctrl+C to stop the service.\n');
}

process.on('SIGINT', () => {
  console.log('\n\nShutting down oracle service...');
  printStats();
  console.log('Goodbye!\n');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n\nShutting down oracle service...');
  printStats();
  console.log('Goodbye!\n');
  process.exit(0);
});

start().catch((error) => {
  console.error('Fatal error starting service:', error);
  process.exit(1);
});
