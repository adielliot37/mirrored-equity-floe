# System Architecture


## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     External Price Sources                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Chainlink  │  │Yahoo Finance │  │  Swarm API   │          │
│  │ Data Streams │  │     API      │  │  (Future)    │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                   │
└─────────┼──────────────────┼──────────────────┼───────────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Price Source Layer                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌───────────────────────────────┐  ┌──────────────────────┐   │
│  │ ChainlinkDataStreamsAdapter   │  │ ManualPriceAdapter   │   │
│  │                                │  │                      │   │
│  │ - Fetches from Chainlink      │  │ - Accepts manual     │   │
│  │ - Validates aggregator        │  │   price updates      │   │
│  │ - Implements IPriceSource     │  │ - Authorization      │   │
│  └───────────────┬───────────────┘  └──────────┬───────────┘   │
│                  │                               │               │
│                  └───────────┬───────────────────┘               │
│                              │                                   │
└──────────────────────────────┼───────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Oracle Layer                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│              ┌────────────────────────────────────┐              │
│              │    EquityOracleAdapter (NVDA)     │              │
│              │                                    │              │
│              │  - Implements AggregatorV2V3       │              │
│              │  - Staleness validation (6hrs)     │              │
│              │  - Price validation                │              │
│              │  - Feed: NVDA/USD                  │              │
│              └───────────────┬────────────────────┘              │
│                              │                                   │
│    ┌─────────────────────────┼─────────────────────────┐        │
│    │                         │                         │        │
│    ▼                         ▼                         ▼        │
│ ┌────────────┐         ┌────────────┐         ┌────────────┐   │
│ │   AAPL     │         │   TSLA     │         │   Others   │   │
│ │  Oracle    │         │  Oracle    │         │  Oracles   │   │
│ └────────────┘         └────────────┘         └────────────┘   │
│                                                                   │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Floe Protocol Layer                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│              ┌────────────────────────────────────┐              │
│              │       Floe PriceOracle             │              │
│              │                                    │              │
│              │  - Aggregates oracle prices        │              │
│              │  - Asset price management          │              │
│              │  - Interface: getAssetPrice()      │              │
│              └───────────────┬────────────────────┘              │
│                              │                                   │
│              ┌───────────────┴────────────────┐                 │
│              │                                │                 │
│              ▼                                ▼                 │
│    ┌────────────────────┐          ┌────────────────────┐      │
│    │ LendingIntentMatch │          │  Liquidation       │      │
│    │ - Creates markets  │          │  Engine            │      │
│    │ - Matches borrows  │          │  - Health checks   │      │
│    └────────────────────┘          └────────────────────┘      │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

## Component Interactions

### 1. Price Data Flow

```
Yahoo Finance → Backend Service → ManualPriceAdapter 
                                        ↓
                              EquityOracleAdapter
                                        ↓
                                 Floe Protocol
                                        ↓
                              User Borrows/Lends
```

### 2. Oracle Query Flow

```
User Transaction
    ↓
Floe Protocol
    ↓ getAssetPrice(token)
PriceOracle
    ↓ getAssetPriceSource(token)
EquityOracleAdapter
    ↓ latestRoundData()
Price Source (Manual/Chainlink)
    ↓ getLatestPrice(feedId)
Return: (price, timestamp)
```

### 3. Staleness Validation Flow

```
Oracle Request
    ↓
Check: isFeedAvailable()
    ↓
Fetch: getLatestPrice()
    ↓
Validate: price > 0
    ↓
Check: block.timestamp - updatedAt < timeout
    ↓
    ├─ PASS → Return price
    └─ FAIL → Revert PriceTooStale
```

## Interface Hierarchy

```
AggregatorV2V3Interface (Chainlink Standard)
    ↑
    │ implements
    │
EquityOracleAdapter
    │
    │ uses
    ↓
IPriceSource (Custom Interface)
    ↑
    │ implements
    ├─────────────────────┬─────────────────────┐
    │                     │                     │
ManualPriceAdapter  ChainlinkAdapter    (Future Adapters)
```

## Contract Relationships

```
┌──────────────────────────────────────────────────────────┐
│                    MockEquityToken                        │
│                    (ERC20 Standard)                       │
│                                                           │
│  - name: "NVIDIA Token"                                  │
│  - symbol: "NVDA"                                        │
│  - decimals: 18                                          │
│  - totalSupply: 1,000,000                                │
└─────────────────────┬────────────────────────────────────┘
                      │ token reference
                      ▼
┌──────────────────────────────────────────────────────────┐
│              EquityOracleAdapter                          │
│                                                           │
│  immutable:                                              │
│    - equityToken: address                                │
│    - feedId: bytes32                                     │
│    - priceSource: IPriceSource                           │
│    - stalenessTimeout: uint256                           │
│    - decimals: uint8                                     │
│                                                           │
│  functions:                                              │
│    - latestRoundData()                                   │
│    - latestAnswer()                                      │
│    - checkStaleness()                                    │
└─────────────────────┬────────────────────────────────────┘
                      │ price source
                      ▼
┌──────────────────────────────────────────────────────────┐
│              ManualPriceAdapter                           │
│                                                           │
│  storage:                                                │
│    - prices: mapping(bytes32 => PriceData)               │
│    - owner: address                                      │
│    - isAuthorized: mapping(address => bool)              │
│                                                           │
│  functions:                                              │
│    - updatePrice(feedId, price)                          │
│    - getLatestPrice(feedId)                              │
│    - isFeedAvailable(feedId)                             │
└──────────────────────────────────────────────────────────┘
```

## Data Structures

### PriceData (ManualPriceAdapter)

```solidity
struct PriceData {
    uint256 price;       // Price in 8 decimals (USD)
    uint256 timestamp;   // Block timestamp of update
    bool exists;         // Feed availability flag
}
```

### Feed Identifier Pattern

```solidity
bytes32 feedId = keccak256("NVDA/USD");
// Result: 0xd7f402a699378a97cf4b1f46fb772a465535d2fead1457bcb27b58312638e264
```

## Security Model

### Access Control

```
ManualPriceAdapter
├─ owner (deployer)
│  └─ Can authorize updaters
└─ authorized addresses
   └─ Can update prices

EquityOracleAdapter
└─ immutable configuration
   └─ No admin functions
   └─ Parameters fixed at deployment
```

### Validation Layers

1. **Price Validation**: Rejects zero prices
2. **Staleness Check**: Enforces time limits
3. **Feed Availability**: Verifies feed exists
4. **Authorization**: Only authorized can update
5. **Immutability**: Core parameters unchangeable

## Deployment Architecture

### Testnet (Base Sepolia)

```
Deployer Wallet (0xa508...)
    │
    ├─> ManualPriceAdapter
    │   └─> NVDA Feed ID configured
    │
    ├─> EquityOracleAdapter (NVDA)
    │   └─> References ManualPriceAdapter
    │
    └─> MockEquityToken (NVDA)
        └─> 1M tokens minted to deployer
```

### Production (Base Mainnet)

```
Governance/Admin
    │
    ├─> ChainlinkDataStreamsAdapter
    │   └─> Real equity feeds configured
    │
    ├─> EquityOracleAdapter (Multiple)
    │   ├─> NVDA Oracle
    │   ├─> AAPL Oracle
    │   └─> TSLA Oracle
    │
    └─> Swarm Protocol Tokens
        └─> Real mirrored equities
```

## Scalability

### Adding New Equity Tokens

```
1. Deploy/Identify equity token
2. Configure price feed in adapter
3. Deploy EquityOracleAdapter
4. Register with Floe's PriceOracle
5. Create lending market
```

### Upgrading Price Sources

```
1. Deploy new price source adapter
2. Deploy new EquityOracleAdapter
3. Update Floe's PriceOracle registration
4. Deprecate old oracle (gradual)
```

## Performance Considerations

### Gas Costs

- **Price Update**: ~50,000 gas (ManualPriceAdapter)
- **Price Query**: ~30,000 gas (read-only)
- **Oracle Deployment**: ~1,500,000 gas
- **Market Creation**: Varies by Floe implementation

### Optimization Strategies

1. **Batch Updates**: Update multiple feeds in one transaction
2. **Cache Results**: Oracle reads are view functions
3. **Immutable Storage**: Reduces SLOAD costs
4. **Custom Errors**: Cheaper than string reverts

## Future Enhancements

### Planned Features

1. **Fallback Oracles**: Secondary price source
2. **Time-Weighted Average**: TWAP price calculation
3. **Circuit Breakers**: Automatic pause on anomalies
4. **Multi-Source Aggregation**: Combine multiple feeds
5. **Dynamic Staleness**: Adjust based on market hours

### Integration Roadmap

```
Phase 1: Manual Price Feeds (Current)
    └─ ManualPriceAdapter with backend service

Phase 2: Chainlink Integration
    └─ ChainlinkDataStreamsAdapter for real feeds

Phase 3: Multi-Source
    └─ Aggregate multiple price sources

Phase 4: Advanced Features
    └─ TWAP, circuit breakers, governance
```

## Monitoring Points

### Critical Metrics

1. **Price Freshness**: Time since last update
2. **Oracle Health**: Successful queries per hour
3. **Price Deviation**: Comparison with market price
4. **Gas Usage**: Update transaction costs
5. **Liquidation Rate**: Market health indicator

### Alert Triggers

- Price not updated in 6+ hours
- Price deviates >10% from expected
- Oracle query failure rate >5%
- Gas costs spike >2x normal
- Liquidation rate >10%

## Reference Implementation

See deployed contracts:
- ManualPriceAdapter: `0xbBD700ca8Fc326c90BA90A028fC1C7b36b0e9D7B`
- NVDA Oracle: `0xC0bC892cbA12632055B7961639E3bB6A3253B17c`
- NVDA Token: `0x370627bb90F37907bE2293a60d77e4938b35FAbA`
