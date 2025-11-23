# Market Configuration Guide


### Core Parameters

Each market requires configuration of the following parameters:

1. **LTV (Loan-to-Value)**: Maximum loan amount relative to collateral value
2. **Interest Rate**: Annual percentage rate charged to borrowers
3. **Liquidation Incentive**: Bonus awarded to liquidators
4. **Market Fee**: Protocol fee on interest payments
5. **Staleness Timeout**: Maximum age of acceptable price data

## LTV Recommendations by Stock Type

### Blue-Chip Equities

**Examples:** AAPL (Apple), MSFT (Microsoft), GOOGL (Google), JNJ (Johnson & Johnson)

**Characteristics:**
- Large market cap ($500B+)
- High liquidity
- Lower volatility
- Stable business models
- Strong balance sheets

**Recommended Parameters:**
```solidity
uint256 ltvBps = 6000;                    // 60% LTV
uint256 interestRateBps = 400;            // 4% annual
uint256 liquidationIncentiveBps = 500;    // 5% bonus
uint256 marketFeeBps = 100;               // 1% protocol fee
uint256 stalenessTimeout = 21600;         // 6 hours
```

**Rationale:**
- Higher LTV justified by lower volatility
- Lower interest rate attracts borrowers
- Moderate liquidation incentive sufficient
- Shorter staleness timeout for active markets

### Growth/Tech Stocks

**Examples:** NVDA (NVIDIA), TSLA (Tesla), META (Meta), AMZN (Amazon)

**Characteristics:**
- High growth potential
- Higher volatility (30-50% annual)
- Large but variable market caps
- News-sensitive
- Rapid price movements

**Recommended Parameters:**
```solidity
uint256 ltvBps = 4500;                    // 45% LTV
uint256 interestRateBps = 600;            // 6% annual
uint256 liquidationIncentiveBps = 700;    // 7% bonus
uint256 marketFeeBps = 150;               // 1.5% protocol fee
uint256 stalenessTimeout = 43200;         // 12 hours
```

**Rationale:**
- Lower LTV protects against volatility
- Higher interest rate compensates for risk
- Increased liquidation incentive for rapid execution
- Extended staleness for after-hours volatility

### Mid-Cap Stocks

**Examples:** PLTR (Palantir), COIN (Coinbase), RBLX (Roblox)

**Characteristics:**
- Market cap $10B-$200B
- Moderate liquidity
- Medium volatility
- Growth-oriented
- Sector-specific risks

**Recommended Parameters:**
```solidity
uint256 ltvBps = 5000;                    // 50% LTV
uint256 interestRateBps = 550;            // 5.5% annual
uint256 liquidationIncentiveBps = 600;    // 6% bonus
uint256 marketFeeBps = 125;               // 1.25% protocol fee
uint256 stalenessTimeout = 28800;         // 8 hours
```

**Rationale:**
- Balanced approach between blue-chip and growth
- Moderate parameters across the board
- Flexible staleness for lower liquidity

### Small-Cap/Volatile Stocks

**Examples:** Stocks <$10B market cap, penny stocks, highly volatile securities

**Characteristics:**
- Small market cap (<$10B)
- Lower liquidity
- High volatility (50%+ annual)
- Higher manipulation risk
- Wider bid-ask spreads

**Recommended Parameters:**
```solidity
uint256 ltvBps = 3500;                    // 35% LTV
uint256 interestRateBps = 800;            // 8% annual
uint256 liquidationIncentiveBps = 1000;   // 10% bonus
uint256 marketFeeBps = 200;               // 2% protocol fee
uint256 stalenessTimeout = 86400;         // 24 hours
```

**Rationale:**
- Very conservative LTV for protection
- Higher interest compensates for risk
- Large liquidation incentive ensures execution
- Extended staleness for illiquid markets

## Interest Rate Guidelines

### Fixed vs Variable Rates

**Fixed Rates:**
- Predictable for borrowers
- Simpler to implement
- May be suboptimal during volatility changes
- Recommended for initial deployment

**Variable Rates (Future Enhancement):**
- Adjust based on utilization
- More capital efficient
- Requires utilization tracking
- Consider for production

### Rate Calculation Factors

Consider these factors when setting rates:

1. **Base Risk-Free Rate**: Current T-Bill rate (4-5%)
2. **Equity Risk Premium**: 3-8% depending on stock type
3. **Liquidation Risk**: 1-3% for execution uncertainty
4. **Protocol Margin**: 0.5-1% for protocol sustainability

**Example Calculation (Blue-Chip):**
```
Base Rate:           4.0%
Equity Risk Premium: 3.0%
Liquidation Risk:    1.0%
Protocol Margin:     0.5%
                    ------
Total:               8.5% → Round to 8% or 9%
```

However, competitive rates may be lower (4-6%) to attract users.

## Liquidation Incentive Best Practices

### Incentive Structure

The liquidation incentive must be:
1. High enough to compensate liquidators for gas costs
2. High enough to encourage prompt liquidations
3. Low enough to protect borrowers from excessive penalties
4. Scaled to the asset's volatility

### Recommended Incentives

| Asset Volatility | Liquidation Incentive | Reasoning |
|-----------------|----------------------|-----------|
| Low (<20% annual) | 5% | Minimal urgency, lower gas cost tolerance |
| Medium (20-40%) | 6-7% | Moderate urgency, standard gas cost |
| High (40-60%) | 8-10% | High urgency, must incentivize immediate action |
| Very High (>60%) | 10-15% | Critical urgency, competitive liquidation needed |

### Gas Cost Consideration

Ensure incentive covers gas costs:

```solidity
// Minimum liquidation size to be profitable
uint256 minCollateral = (averageGasCost * gasPrice * ethPrice) / (liquidationIncentive * collateralPrice);

// Example: $50 gas, 7% incentive, $100 collateral price
// minCollateral = $50 / (0.07 * $100) = ~7 tokens
```

## Risk Assessment Guidelines

### Volatility Analysis

Track and adjust for volatility:

```solidity
// Historical volatility check
uint256 annualVolatility = calculateVolatility(priceHistory, 252); // 252 trading days

if (annualVolatility > 60%) {
    // High volatility: Lower LTV, higher incentives
    ltvBps = 3500;
    liquidationIncentiveBps = 1000;
} else if (annualVolatility > 40%) {
    // Medium volatility
    ltvBps = 4500;
    liquidationIncentiveBps = 700;
} else {
    // Low volatility
    ltvBps = 6000;
    liquidationIncentiveBps = 500;
}
```

### Liquidity Risk

Assess market liquidity:

```solidity
// Check trading volume
uint256 avgDailyVolume = getAverageDailyVolume(token, 30 days);
uint256 marketCap = getMarketCap(token);
uint256 liquidityRatio = (avgDailyVolume * 100) / marketCap;

// High liquidity: >1% of market cap traded daily
// Medium liquidity: 0.1-1% of market cap
// Low liquidity: <0.1% of market cap
```

## Example Market Configurations

### Configuration 1: NVIDIA (NVDA) Collateral Market

```solidity
// NVIDIA/USDC Lending Market
address loanToken = USDC_ADDRESS;
address collateralToken = NVDA_TOKEN_ADDRESS;

MarketConfig memory config = MarketConfig({
    ltvBps: 4500,                    // 45% LTV
    interestRateBps: 600,            // 6% annual
    liquidationIncentiveBps: 700,    // 7% bonus
    marketFeeBps: 150,               // 1.5% fee
    stalenessTimeout: 43200          // 12 hours
});

// Rationale:
// - NVDA is volatile (40-50% annual volatility)
// - High liquidity supports moderate LTV
// - Tech stock requires higher incentive for quick liquidation
```

### Configuration 2: Apple (AAPL) Collateral Market

```solidity
// Apple/USDC Lending Market
address loanToken = USDC_ADDRESS;
address collateralToken = AAPL_TOKEN_ADDRESS;

MarketConfig memory config = MarketConfig({
    ltvBps: 6000,                    // 60% LTV
    interestRateBps: 400,            // 4% annual
    liquidationIncentiveBps: 500,    // 5% bonus
    marketFeeBps: 100,               // 1% fee
    stalenessTimeout: 21600          // 6 hours
});

// Rationale:
// - AAPL is stable (~25% volatility)
// - Massive liquidity supports higher LTV
// - Blue-chip status allows competitive rates
```

### Configuration 3: Tesla (TSLA) Collateral Market

```solidity
// Tesla/USDC Lending Market
address loanToken = USDC_ADDRESS;
address collateralToken = TSLA_TOKEN_ADDRESS;

MarketConfig memory config = MarketConfig({
    ltvBps: 4000,                    // 40% LTV
    interestRateBps: 700,            // 7% annual
    liquidationIncentiveBps: 800,    // 8% bonus
    marketFeeBps: 150,               // 1.5% fee
    stalenessTimeout: 43200          // 12 hours
});

// Rationale:
// - TSLA is highly volatile (50-70% volatility)
// - News-sensitive requires conservative LTV
// - High incentive needed for rapid liquidation
```

### Configuration 4: ETF Collateral Market

```solidity
// SPY (S&P 500 ETF) / USDC Lending Market
address loanToken = USDC_ADDRESS;
address collateralToken = SPY_TOKEN_ADDRESS;

MarketConfig memory config = MarketConfig({
    ltvBps: 7000,                    // 70% LTV
    interestRateBps: 350,            // 3.5% annual
    liquidationIncentiveBps: 400,    // 4% bonus
    marketFeeBps: 75,                // 0.75% fee
    stalenessTimeout: 21600          // 6 hours
});

// Rationale:
// - ETFs have lowest volatility (~15%)
// - Diversification reduces risk
// - Can support highest LTV safely
```

## Market Monitoring

### Key Metrics to Track

1. **Utilization Rate**
   ```solidity
   uint256 utilization = (totalBorrowed * 10000) / totalSupplied;
   // Target: 60-80% utilization
   ```

2. **Liquidation Frequency**
   ```solidity
   uint256 liquidationRate = (liquidations * 10000) / totalLoans;
   // Target: <5% liquidation rate
   ```

3. **Average Health Factor**
   ```solidity
   uint256 avgHealth = calculateAverageHealthFactor();
   // Target: >1.5 average health factor
   ```

### Adjustment Triggers

Adjust parameters when:

- Liquidation rate >10%: Decrease LTV by 5-10%
- Utilization <40%: Increase LTV or decrease rates
- Utilization >90%: Decrease LTV or increase rates
- Multiple stale price incidents: Increase staleness timeout
- High volatility period: Temporarily decrease LTV

## Parameter Update Process

### Safe Parameter Changes

```solidity
// Gradual LTV adjustment (safer)
function adjustLTV(uint256 currentLTV, uint256 targetLTV) internal pure returns (uint256) {
    uint256 maxChange = 500; // 5% maximum change per update
    
    if (targetLTV > currentLTV) {
        return currentLTV + min(targetLTV - currentLTV, maxChange);
    } else {
        return currentLTV - min(currentLTV - targetLTV, maxChange);
    }
}

// Update with governance delay
function updateMarketParams(
    address market,
    uint256 newLTV,
    uint256 newRate
) external onlyGovernance {
    // Queue change with 48-hour timelock
    queueParameterChange(market, newLTV, newRate, block.timestamp + 48 hours);
}
```

## Testing Recommendations

### Stress Testing Scenarios

1. **Flash Crash**: 30% price drop in 1 hour
   - Verify liquidations execute
   - Check incentive adequacy
   - Confirm no protocol insolvency

2. **Extended Stale Price**: No price updates for 48 hours
   - Verify staleness detection
   - Test fallback mechanisms
   - Check user protection

3. **High Volatility**: 10% daily swings for 1 week
   - Monitor liquidation frequency
   - Track health factor distribution
   - Assess parameter effectiveness

4. **Low Liquidity**: Reduced trading volume by 80%
   - Test price impact of liquidations
   - Verify slippage protection
   - Check liquidator profitability

## Production Checklist

Before launching markets:

- [ ] Historical volatility analyzed (min 6 months)
- [ ] Liquidity depth verified
- [ ] Liquidation bot tested
- [ ] Oracle reliability confirmed
- [ ] Circuit breakers implemented
- [ ] Emergency pause mechanism ready
- [ ] Parameter adjustment governance in place
- [ ] Insurance fund established (optional)
- [ ] Monitoring dashboard deployed
- [ ] Alert system configured

## Advanced Configurations

### Dynamic Parameters

For sophisticated markets:

```solidity
contract DynamicMarketConfig {
    function getLTV(address asset) external view returns (uint256) {
        uint256 volatility = getVolatility(asset);
        uint256 liquidity = getLiquidityScore(asset);
        
        // Base LTV
        uint256 baseLTV = 5000; // 50%
        
        // Adjust for volatility (lower = higher LTV)
        if (volatility < 20) baseLTV += 1000;
        if (volatility > 40) baseLTV -= 1000;
        
        // Adjust for liquidity (higher = higher LTV)
        if (liquidity > 80) baseLTV += 500;
        if (liquidity < 40) baseLTV -= 500;
        
        return baseLTV;
    }
}
```

### Cross-Market Risk Management

```solidity
// Global exposure limits
uint256 public maxTotalEquityExposure = 10_000_000 * 1e6; // $10M
mapping(address => uint256) public assetExposureCap;

function checkGlobalLimits(address asset, uint256 amount) internal view {
    uint256 newExposure = getCurrentExposure(asset) + amount;
    require(newExposure <= assetExposureCap[asset], "Asset exposure exceeded");
    
    uint256 totalExposure = getTotalEquityExposure() + amount;
    require(totalExposure <= maxTotalEquityExposure, "Global limit exceeded");
}
```

## References

- Historical Volatility Data: Yahoo Finance, TradingView
- Liquidity Metrics: Token Terminal, Dune Analytics
- Risk Models: VaR (Value at Risk), CVaR (Conditional VaR)
- DeFi Lending: Aave, Compound documentation
