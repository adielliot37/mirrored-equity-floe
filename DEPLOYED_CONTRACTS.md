
## Contract Addresses

### Core Infrastructure

| Contract | Address | Explorer Link |
|----------|---------|---------------|
| ManualPriceAdapter | `0xbBD700ca8Fc326c90BA90A028fC1C7b36b0e9D7B` | [View](https://sepolia.basescan.org/address/0xbBD700ca8Fc326c90BA90A028fC1C7b36b0e9D7B) |

### Equity Token (ERC20)

| Token | Address | Initial Supply | Explorer Link |
|-------|---------|----------------|---------------|
| NVDA (NVIDIA) | `0x370627bb90F37907bE2293a60d77e4938b35FAbA` | 1,000,000 NVDA | [View](https://sepolia.basescan.org/address/0x370627bb90F37907bE2293a60d77e4938b35FAbA) |

### Price Oracle (Chainlink Compatible)

| Oracle | Address | Staleness Timeout | Price Source | Explorer Link |
|--------|---------|-------------------|--------------|---------------|
| NVDA Oracle | `0xC0bC892cbA12632055B7961639E3bB6A3253B17c` | 6 hours | Yahoo Finance | [View](https://sepolia.basescan.org/address/0xC0bC892cbA12632055B7961639E3bB6A3253B17c) |

## Current Price

NVIDIA (NVDA): Updated every 5 minutes from Yahoo Finance API

To check the current price:
```bash
cast call 0xC0bC892cbA12632055B7961639E3bB6A3253B17c "latestAnswer()(int256)" --rpc-url https://sepolia.base.org
```

## Quick Start Commands

### Check NVIDIA Price

```bash
cast call 0xC0bC892cbA12632055B7961639E3bB6A3253B17c \
    "latestAnswer()(int256)" \
    --rpc-url https://sepolia.base.org
```

Output: Price in 8 decimals (divide by 10^8 to get USD value)

### Check NVDA Balance

```bash
cast call 0x370627bb90F37907bE2293a60d77e4938b35FAbA \
    "balanceOf(address)(uint256)" \
    0xa508C2c34d17BeaeBeCC12D63B22655B712DE953 \
    --rpc-url https://sepolia.base.org
```

Output: Balance in wei (1,000,000 tokens = 1000000000000000000000000)

### Transfer NVDA Tokens

```bash
cast send 0x370627bb90F37907bE2293a60d77e4938b35FAbA \
    "transfer(address,uint256)" \
    RECIPIENT_ADDRESS \
    100000000000000000000 \
    --rpc-url https://sepolia.base.org \
    --private-key $PRIVATE_KEY
```

Transfers 100 NVDA tokens

### Mint More Tokens (Deployer Only)

```bash
cast send 0x370627bb90F37907bE2293a60d77e4938b35FAbA \
    "mint(address,uint256)" \
    0xa508C2c34d17BeaeBeCC12D63B22655B712DE953 \
    500000000000000000000000 \
    --rpc-url https://sepolia.base.org \
    --private-key $PRIVATE_KEY
```

Mints 500,000 more NVDA tokens

## Oracle Architecture

```
Yahoo Finance API (Real NVIDIA Stock Price)
    ↓
Backend Oracle Service (oracle-service.js)
    ↓ Updates every 5 minutes
ManualPriceAdapter (0xbBD7...9D7B)
    ↓
NVDA Oracle (0xC0bC...B17c)
    ↓
Your Application / Trading Platform
```

Current Setup:
- Using real NVIDIA prices from Yahoo Finance
- Price updates: Every 5 minutes via backend oracle service
- Data source: https://query1.finance.yahoo.com/v8/finance/chart/NVDA
- Real stock prices

## Backend Oracle Service

### Install Dependencies

```bash
npm install
```

### Start Oracle Service

```bash
# Run in foreground
npm start

# Run in background with PM2
npm install -g pm2
npm run pm2
```

### Monitor Oracle Service

```bash
# Check status
pm2 status

# View logs
pm2 logs nvidia-oracle

# Restart
pm2 restart nvidia-oracle

# Stop
pm2 stop nvidia-oracle
```

## Advanced Usage

### Get Full Price Data

```bash
cast call 0xC0bC892cbA12632055B7961639E3bB6A3253B17c \
    "latestRoundData()(uint80,int256,uint256,uint256,uint80)" \
    --rpc-url https://sepolia.base.org
```

Returns:
- Round ID: 0
- Price: Real NVIDIA price (8 decimals)
- Started At: 0
- Updated At: Unix timestamp of last update
- Answered In Round: 0

### Check Price from ManualPriceAdapter

```bash
cast call 0xbBD700ca8Fc326c90BA90A028fC1C7b36b0e9D7B \
    "prices(bytes32)(uint256,uint256,bool)" \
    0xd7f402a699378a97cf4b1f46fb772a465535d2fead1457bcb27b58312638e264 \
    --rpc-url https://sepolia.base.org
```

Returns:
- Price (uint256)
- Timestamp (uint256)
- Exists (bool)

### Check Staleness

```bash
cast call 0xC0bC892cbA12632055B7961639E3bB6A3253B17c \
    "checkStaleness()(bool,uint256)" \
    --rpc-url https://sepolia.base.org
```

Returns:
- Is Stale: false/true
- Age in seconds

### Get Oracle Description

```bash
cast call 0xC0bC892cbA12632055B7961639E3bB6A3253B17c \
    "description()(string)" \
    --rpc-url https://sepolia.base.org
```

Returns: "NVIDIA/USD"

## Example: Calculate Portfolio Value

```python
balance = 1000 * 10**18  # 1000 tokens
price = 269821822426     # $2,698.22 (8 decimals)

portfolio_value = (balance * price) / 10**18 / 10**8
# = 2,698,220 USD
```

## Important Links

### Block Explorers
- Base Sepolia Explorer: https://sepolia.basescan.org/
- Deployer Address: https://sepolia.basescan.org/address/0xa508C2c34d17BeaeBeCC12D63B22655B712DE953

### Chainlink Resources
- Base Sepolia Price Feeds: https://docs.chain.link/data-feeds/price-feeds/addresses?network=base-sepolia
- ETH/USD Feed: https://sepolia.basescan.org/address/0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1

## Environment Variables

Save these in your `.env` file:

```bash
# Deployer
DEPLOYER_ADDRESS=0xa508C2c34d17BeaeBeCC12D63B22655B712DE953

# Core
MANUAL_PRICE_ADAPTER=0xbBD700ca8Fc326c90BA90A028fC1C7b36b0e9D7B

# Token
NVDA_TOKEN=0x370627bb90F37907bE2293a60d77e4938b35FAbA

# Oracle
NVDA_ORACLE=0xC0bC892cbA12632055B7961639E3bB6A3253B17c
```

