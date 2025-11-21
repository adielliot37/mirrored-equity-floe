# EquityOracle 



## Deployed Contracts (Base Sepolia Testnet)

Network: Base Sepolia (Chain ID: 84532)
Deployment Date: November 21, 2025

### Core Infrastructure

| Contract | Address | Description | Explorer |
|----------|---------|-------------|----------|
| ManualPriceAdapter | `0xbBD700ca8Fc326c90BA90A028fC1C7b36b0e9D7B` | Manual price feed adapter | [View](https://sepolia.basescan.org/address/0xbBD700ca8Fc326c90BA90A028fC1C7b36b0e9D7B) |
| NVDA Oracle | `0xC0bC892cbA12632055B7961639E3bB6A3253B17c` | NVIDIA price oracle (6hr timeout) | [View](https://sepolia.basescan.org/address/0xC0bC892cbA12632055B7961639E3bB6A3253B17c) |
| NVDA Token | `0x370627bb90F37907bE2293a60d77e4938b35FAbA` | NVIDIA equity token (ERC20) | [View](https://sepolia.basescan.org/address/0x370627bb90F37907bE2293a60d77e4938b35FAbA) |

See [DEPLOYED_CONTRACTS.md](./DEPLOYED_CONTRACTS.md) for complete deployment details.

## Contract Architecture

### 1. ManualPriceAdapter (0xbBD7...9D7B)
- Purpose: Stores and provides price data from external sources
- Type: Price feed adapter
- Updates: Via backend oracle service (every 5 minutes)
- Interface: Implements IPriceSource interface

### 2. EquityOracleAdapter (0xC0bC...B17c)
- Purpose: Chainlink-compatible oracle that wraps the price adapter
- Type: Oracle aggregator
- Interface: Implements AggregatorV2V3Interface
- Staleness Timeout: 6 hours (configurable)
- Decimals: 8 (standard USD format)
- Features:
  - Price validation (rejects zero prices)
  - Staleness checking
  - Compatible with Floe Protocol's PriceOracle

### 3. MockEquityToken (0x370...FAbA)
- Purpose: ERC20 token representing NVIDIA stock
- Symbol: NVDA
- Decimals: 18
- Supply: 1,000,000 NVDA tokens

## Data Flow

```
Yahoo Finance API (Real Stock Prices)
    ↓
Backend Oracle Service (oracle-service.js)
    ↓ Updates every 5 minutes
ManualPriceAdapter (0xbBD7...9D7B)
    ↓
EquityOracleAdapter (0xC0bC...B17c)
    ↓
Floe Protocol / Your dApp
```

Steps:
1. Backend service fetches NVIDIA price from Yahoo Finance API
2. Service updates ManualPriceAdapter contract on-chain
3. EquityOracleAdapter reads from ManualPriceAdapter
4. Floe Protocol reads from EquityOracleAdapter using standard Chainlink interface

## Quick Start

### Check Current NVIDIA Price

```bash
cast call 0xC0bC892cbA12632055B7961639E3bB6A3253B17c \
    "latestAnswer()(int256)" \
    --rpc-url https://sepolia.base.org
```

Output is in 8 decimals (e.g., 26982182242 = $269.82)

### Get Full Price Data

```bash
cast call 0xC0bC892cbA12632055B7961639E3bB6A3253B17c \
    "latestRoundData()(uint80,int256,uint256,uint256,uint80)" \
    --rpc-url https://sepolia.base.org
```

Returns: (roundId, price, startedAt, updatedAt, answeredInRound)

### Check NVDA Token Balance

```bash
cast call 0x370627bb90F37907bE2293a60d77e4938b35FAbA \
    "balanceOf(address)(uint256)" \
    YOUR_ADDRESS \
    --rpc-url https://sepolia.base.org
```

## Floe Protocol Integration

### Step 1: Add Oracle to Floe's PriceOracle

```solidity
IPriceOracle priceOracle = IPriceOracle(FLOE_PRICE_ORACLE_ADDRESS);

address[] memory assets = new address[](1);
address[] memory sources = new address[](1);

assets[0] = 0x370627bb90F37907bE2293a60d77e4938b35FAbA; // NVDA Token
sources[0] = 0xC0bC892cbA12632055B7961639E3bB6A3253B17c; // NVDA Oracle

priceOracle.setAssetPriceSources(assets, sources);
```

### Step 2: Verify Integration

```solidity
address oracle = priceOracle.getAssetPriceSource(nvidiaToken);
require(oracle == 0xC0bC892cbA12632055B7961639E3bB6A3253B17c);

uint256 price = priceOracle.getAssetPrice(nvidiaToken);
require(price > 0, "Invalid price");
```

### Step 3: Create Lending Market

```solidity
ILendingIntentMatcher(floeMatcher).createMarket(
    usdcAddress,        // Loan token
    nvidiaToken,        // Collateral (NVDA)
    500,                // 5% annual interest
    5000,               // 50% LTV
    100,                // 1% protocol fee
    500                 // 5% liquidation incentive
);
```

## Running the Oracle Service

### Install Dependencies

```bash
cd equity-oracle
npm install
```

### Start Service

```bash
# Run in foreground
npm start

# Or run with PM2 (background)
npm install -g pm2
pm2 start oracle-service.js --name nvidia-oracle
```

### Monitor Service

```bash
pm2 status
pm2 logs nvidia-oracle
pm2 restart nvidia-oracle
```

## Environment Setup

Create a `.env` file:

```bash
# RPC and Keys
PRIVATE_KEY=your_private_key_here
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASESCAN_API_KEY=your_basescan_api_key

# Deployed Addresses
MANUAL_PRICE_ADAPTER=0xbBD700ca8Fc326c90BA90A028fC1C7b36b0e9D7B
NVDA_ORACLE=0xC0bC892cbA12632055B7961639E3bB6A3253B17c
NVDA_TOKEN=0x370627bb90F37907bE2293a60d77e4938b35FAbA
```

## Development

### Build Contracts

```bash
forge build
```

### Run Tests

```bash
forge test
forge test -vvv
```

### Deploy New Oracle

```bash
forge script script/DeployEquityOracle.s.sol:DeployEquityOracle \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --verify
```

## Contract Interfaces

### AggregatorV2V3Interface (Chainlink Standard)

```solidity
interface AggregatorV2V3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function latestAnswer() external view returns (int256);
    function latestTimestamp() external view returns (uint256);
    function latestRoundData() 
        external view 
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}
```

### IPriceSource (Internal Interface)

```solidity
interface IPriceSource {
    function getLatestPrice(bytes32 feedId) 
        external view 
        returns (int256 price, uint256 timestamp);
    function isFeedAvailable(bytes32 feedId) 
        external view 
        returns (bool);
}
```

## Configuration Parameters

### Staleness Timeouts

| Market Type | Timeout | Use Case |
|------------|---------|----------|
| Market Hours | 6 hours | Active trading |
| Extended | 24 hours | Weekends/holidays |
| Conservative | 12 hours | Balanced approach |

### Recommended LTV Ratios

| Stock Type | LTV | Liquidation Incentive |
|-----------|-----|----------------------|
| Blue-chip (AAPL, MSFT) | 50-60% | 5% |
| Growth (NVDA, TSLA) | 40-50% | 7% |
| Small-cap | 30-40% | 10% |
