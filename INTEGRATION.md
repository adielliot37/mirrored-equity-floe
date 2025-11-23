# Floe Protocol Integration Guide


## Prerequisites

Before starting integration:

- [ ] Deployed EquityOracleAdapter contracts
- [ ] Configured price source adapter (ManualPriceAdapter or ChainlinkDataStreamsAdapter)
- [ ] Admin/governance access to Floe's PriceOracle contract
- [ ] Mirrored equity tokens (Swarm Protocol, xStocks, or mock tokens)
- [ ] Base Sepolia testnet ETH for transactions

## Integration Steps

### Step 1: Deploy Price Source Adapter

Choose your price source:

**Option A: ManualPriceAdapter (Recommended for Testing)**

```solidity
ManualPriceAdapter priceSource = new ManualPriceAdapter();
```

**Option B: ChainlinkDataStreamsAdapter (Production)**

```solidity
ChainlinkDataStreamsAdapter priceSource = new ChainlinkDataStreamsAdapter();
bytes32 nvdaFeedId = keccak256("NVDA/USD");
priceSource.addFeed(nvdaFeedId, CHAINLINK_NVDA_AGGREGATOR);
```

### Step 2: Deploy EquityOracleAdapter

Deploy an oracle for each equity token:

```solidity
EquityOracleAdapter nvidiaOracle = new EquityOracleAdapter(
    nvidiaTokenAddress,      // Address of NVDA token
    keccak256("NVDA/USD"),   // Feed identifier
    address(priceSource),    // Price source adapter
    21600,                   // 6 hours staleness timeout
    8,                       // 8 decimals (USD standard)
    "NVIDIA/USD"             // Description
);
```

**Staleness Timeout Guidelines:**
- Market Hours: 21600 seconds (6 hours)
- Extended Trading: 43200 seconds (12 hours)
- Including Weekends: 86400 seconds (24 hours)

### Step 3: Register Oracle with Floe's PriceOracle

This requires governance/admin access:

```solidity
// Get Floe's PriceOracle contract
IPriceOracle floePriceOracle = IPriceOracle(FLOE_PRICE_ORACLE_ADDRESS);

// Prepare arrays for batch registration
address[] memory assets = new address[](1);
address[] memory sources = new address[](1);

assets[0] = nvidiaTokenAddress;
sources[0] = address(nvidiaOracle);

// Register oracle (requires admin access)
floePriceOracle.setAssetPriceSources(assets, sources);
```

### Step 4: Configure Staleness Timeout in Floe

If Floe's PriceOracle supports configurable staleness timeouts:

```solidity
// Set staleness timeout for equity assets
// Equities need longer timeouts than crypto assets
floePriceOracle.setStalenessTimeout(
    nvidiaTokenAddress,
    21600  // 6 hours in seconds
);
```

If Floe doesn't support per-asset staleness configuration, ensure EquityOracleAdapter's internal staleness check is sufficient.

### Step 5: Verify Integration

Test the oracle connection:

```solidity
// Verify oracle is registered
address registeredOracle = floePriceOracle.getAssetPriceSource(nvidiaTokenAddress);
require(registeredOracle == address(nvidiaOracle), "Oracle not registered");

// Test price fetching
uint256 price = floePriceOracle.getAssetPrice(nvidiaTokenAddress);
require(price > 0, "Invalid price");

// Check price freshness
(, int256 answer,, uint256 updatedAt,) = nvidiaOracle.latestRoundData();
require(block.timestamp - updatedAt < 21600, "Price too stale");
```

### Step 6: Create Lending Market

Create a market using Floe's LendingIntentMatcher:

```solidity
ILendingIntentMatcher floeMatcher = ILendingIntentMatcher(FLOE_MATCHER_ADDRESS);

// Market parameters for NVIDIA/USDC
address loanToken = usdcAddress;              // Loan currency
address collateralToken = nvidiaTokenAddress; // Collateral
uint256 interestRateBps = 500;               // 5% annual interest
uint256 ltvBps = 5000;                       // 50% LTV
uint256 marketFeeBps = 100;                  // 1% protocol fee
uint256 liquidationIncentiveBps = 500;       // 5% liquidation bonus

// Create market
floeMatcher.createMarket(
    loanToken,
    collateralToken,
    interestRateBps,
    ltvBps,
    marketFeeBps,
    liquidationIncentiveBps
);
```

See [MARKET_CONFIG.md](./MARKET_CONFIG.md) for recommended parameters by equity type.

## Troubleshooting

### Issue: Oracle Not Recognized by Floe

**Symptoms:** Floe cannot fetch prices, `getAssetPriceSource()` returns zero address.

**Solutions:**
1. Verify oracle registration:
   ```solidity
   address oracle = floePriceOracle.getAssetPriceSource(token);
   console.log("Registered oracle:", oracle);
   ```

2. Check admin permissions:
   ```solidity
   address admin = floePriceOracle.owner(); // or governance()
   require(msg.sender == admin, "Not authorized");
   ```

3. Re-register if needed:
   ```solidity
   floePriceOracle.setAssetPriceSources(assets, sources);
   ```

### Issue: "Price Too Stale" Error

**Symptoms:** Transactions revert with "Price too stale" or `PriceTooStale()` error.

**Cause:** Price data is older than staleness timeout (equities don't trade 24/7).

**Solutions:**

1. **Increase staleness timeout** (recommended for equities):
   ```solidity
   // Use 24-hour timeout for weekends/holidays
   EquityOracleAdapter oracle = new EquityOracleAdapter(
       token,
       feedId,
       priceSource,
       86400,  // 24 hours
       8,
       description
   );
   ```

2. **Update price feed**:
   ```solidity
   // For ManualPriceAdapter
   manualAdapter.updatePrice(feedId, newPrice);
   ```

3. **Check market hours**: Ensure your staleness timeout accounts for:
   - Market close (4:00 PM ET)
   - Weekends (Friday 4:00 PM - Monday 9:30 AM ET)
   - Holidays

### Issue: "Invalid Price" Error

**Symptoms:** Transactions revert with "Invalid price" or `InvalidPrice()` error.

**Cause:** Oracle returning zero price.

**Solutions:**

1. **Check price source**:
   ```solidity
   (uint256 price, uint256 timestamp) = priceSource.getLatestPrice(feedId);
   console.log("Price:", price);
   console.log("Timestamp:", timestamp);
   ```

2. **Verify feed configuration**:
   ```solidity
   bool available = priceSource.isFeedAvailable(feedId);
   require(available, "Feed not configured");
   ```

3. **Test oracle directly**:
   ```bash
   cast call <ORACLE_ADDRESS> "latestAnswer()(int256)" --rpc-url <RPC_URL>
   ```

### Issue: "Feed Unavailable" Error

**Symptoms:** Transactions revert with "Feed unavailable" or `FeedUnavailable()` error.

**Cause:** Price feed not configured in adapter.

**Solutions:**

1. **Add feed to adapter**:
   ```solidity
   // For ChainlinkDataStreamsAdapter
   adapter.addFeed(keccak256("NVDA/USD"), CHAINLINK_AGGREGATOR);
   
   // For ManualPriceAdapter
   manualAdapter.updatePrice(keccak256("NVDA/USD"), initialPrice);
   ```

2. **Verify feed ID matches**:
   ```solidity
   bytes32 expectedFeedId = keccak256("NVDA/USD");
   bytes32 oracleFeedId = oracle.feedId();
   require(expectedFeedId == oracleFeedId, "Feed ID mismatch");
   ```

### Issue: Liquidations Not Working

**Symptoms:** Underwater positions not liquidated.

**Solutions:**

1. **Check liquidation incentive**: Must be attractive enough for liquidators
   ```solidity
   // 5-10% is typical
   uint256 liquidationIncentiveBps = 500; // 5%
   ```

2. **Verify price updates**: Ensure oracle service is running
   ```bash
   pm2 status nvidia-oracle
   ```

3. **Check LTV settings**: Ensure sufficient buffer
   ```solidity
   // Example: 50% LTV with 5% incentive = 55% liquidation threshold
   uint256 ltvBps = 5000;  // 50%
   uint256 incentiveBps = 500; // 5%
   ```

## Integration Checklist

Use this checklist to verify complete integration:

### Pre-Integration
- [ ] EquityOracleAdapter deployed for each equity token
- [ ] Price source adapter configured with feeds
- [ ] Admin access to Floe's PriceOracle confirmed
- [ ] Equity tokens available (Swarm Protocol or test tokens)

### Integration
- [ ] Oracles registered with Floe's PriceOracle
- [ ] Staleness timeouts configured appropriately
- [ ] Price fetching tested and working
- [ ] Markets created for each equity/loan pair

### Post-Integration Testing
- [ ] Price queries return valid data
- [ ] Staleness validation working correctly
- [ ] Borrow intents can be created
- [ ] Lend intents can be matched
- [ ] Liquidations execute properly
- [ ] Interest accrual functioning

### Production Readiness
- [ ] Oracle service deployed and monitored
- [ ] Backup price sources configured
- [ ] Alerting set up for stale prices
- [ ] Circuit breakers tested
- [ ] Emergency pause mechanisms verified

## Advanced Configuration

### Multiple Equity Oracles

To add multiple equity tokens:

```solidity
// Deploy oracles
EquityOracleAdapter nvdaOracle = deployOracle(nvdaToken, "NVDA/USD");
EquityOracleAdapter aaplOracle = deployOracle(aaplToken, "AAPL/USD");
EquityOracleAdapter tslaOracle = deployOracle(tslaToken, "TSLA/USD");

// Batch register
address[] memory assets = new address[](3);
address[] memory sources = new address[](3);

assets[0] = nvdaToken; sources[0] = address(nvdaOracle);
assets[1] = aaplToken; sources[1] = address(aaplOracle);
assets[2] = tslaToken; sources[2] = address(tslaOracle);

floePriceOracle.setAssetPriceSources(assets, sources);
```

### Custom Staleness Policy

Different equities may need different staleness timeouts:

```solidity
// Blue-chip: 6 hours (active market)
EquityOracleAdapter aaplOracle = new EquityOracleAdapter(
    aaplToken, feedId, priceSource, 21600, 8, "AAPL/USD"
);

// Volatile/Small-cap: 24 hours (less liquid)
EquityOracleAdapter volatileOracle = new EquityOracleAdapter(
    volatileToken, feedId, priceSource, 86400, 8, "VOLATILE/USD"
);
```

### Fallback Oracles

For critical markets, implement fallback oracles:

```solidity
contract OracleWithFallback {
    IOracle public primaryOracle;
    IOracle public fallbackOracle;
    
    function getPrice() external view returns (uint256) {
        try primaryOracle.latestAnswer() returns (int256 price) {
            if (price > 0) return uint256(price);
        } catch {}
        
        return uint256(fallbackOracle.latestAnswer());
    }
}
```

## Monitoring and Maintenance

### Price Update Monitoring

Monitor oracle service health:

```bash
# Check service status
pm2 status nvidia-oracle

# View logs
pm2 logs nvidia-oracle --lines 100

# Check last update time
cast call <ORACLE_ADDRESS> "latestTimestamp()(uint256)" --rpc-url <RPC>
```

### Staleness Alerts

Set up alerts for stale prices:

```solidity
function checkAllOracles() external view returns (bool[] memory stale) {
    stale = new bool[](oracles.length);
    for (uint i = 0; i < oracles.length; i++) {
        (bool isStale,) = oracles[i].checkStaleness();
        stale[i] = isStale;
    }
}
```

### Regular Maintenance Tasks

- Daily: Verify oracle service running
- Weekly: Check price update frequency
- Monthly: Review staleness timeout appropriateness
- Quarterly: Audit oracle security

## Support

For integration assistance:
- Review [README.md](./README.md) for system overview
- Check [MARKET_CONFIG.md](./MARKET_CONFIG.md) for market parameters
- See [DEPLOYED_CONTRACTS.md](./DEPLOYED_CONTRACTS.md) for deployed addresses
- Test with [script/ConfigureMarkets.s.sol](./script/ConfigureMarkets.s.sol)

## References

- Floe Protocol Documentation
- Chainlink Price Feeds: https://docs.chain.link/data-feeds
- Swarm Protocol: https://swarm.com
- Base Sepolia Explorer: https://sepolia.basescan.org
