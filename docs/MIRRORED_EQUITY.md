## Mirrored Equity Architecture

This repo mirrors publicly traded assets (e.g., NVDA stock) into ERC‑20 tokens that can be used inside Floe’s lending markets. The flow matches the guidance in Floe’s November 13, 2025 changelog: prices are kept off-chain until they reach the oracle layer, TVL is tracked off-chain, and lending APRs are derived from pool utilization for real-time responsiveness ([Floe Docs](https://floe-labs.gitbook.io/docs)).

### Tokenization Pipeline

1. **Off-chain price fetcher** (`oracle-service.js`) pulls live quotes (e.g., Yahoo Finance for NVDA) every ~5 minutes.
2. **ManualPriceAdapter** stores the latest signed price per `feedId`. Only authorized publishers can update it.
3. **EquityOracleAdapter** exposes a Chainlink-compatible `AggregatorV2V3Interface` for each mirrored equity. It enforces staleness, non-zero prices, and references the adapter for data.
4. **MockEquityToken** (e.g., NVDA) mints 18-decimal ERC-20 tokens representing fractional exposure to the real asset.

Because the oracle adapter is asset-agnostic, the same pattern supports equities, ETFs, indexes, or even off-chain baskets. Deploy a new token + adapter pair, register it with Floe’s PriceOracle, and the lending market can treat it like any other collateral.

### Collateral & Pricing Math

- Oracle prices are stored with 8 decimals (e.g., `$1,234.56` → `123456000`).
- Borrowing uses 6-decimal USDC. To keep everything in the same unit, the pool normalizes NVDA collateral into USD (6 decimals) before applying risk parameters.
- **Required collateral** for a borrow request is:

  ```
  collateralRequired = (borrowAmount * BPS_DENOM / LTV_BPS) / price
  ```

  - `BPS_DENOM = 10_000`
  - `LTV_BPS = 6_000` (60% LTV)
  - `price` comes from the oracle, scaled back to 6 decimals before division.

- **Health factor** mirrors Aave-style math: `(collateralUSD * LIQ_THRESHOLD_BPS) / (debtUSD * BPS_DENOM)`.
- The front-end calls the on-chain `collateralRequired()` view so planned borrows always show the exact NVDA deposit needed before users hit “Borrow”.

### Lending/Liquidation Flow

1. User enters desired mUSDC amount + duration. UI fetches `collateralRequired()` and displays total + “still needed” NVDA.
2. User deposits NVDA (or tops up) and borrows. The pool tracks scaled debt plus the borrower’s principal.
3. Interest accrues linearly with time/utilization. Repayments must be in mUSDC; borrowers can’t withdraw NVDA until all debt is cleared.
4. If health factor < 1.0, liquidators repay debt in mUSDC and seize NVDA at a 5% bonus.

### Lender Accounting

- Deposits accrue interest through the `liquidityIndex`, but the pool also tracks principal per lender.
- `getLenderPosition()` now returns `(balance, principal, interest)`, so the UI can display live USDC earnings without off-chain bookkeeping.
- Pool-wide stats (`getPoolStats`) surface total deposits, total debt, and available liquidity so dashboards can show the same metrics as major lending markets (Aave, Compound, etc.).

### Extending to New Assets

To list another mirrored asset:

1. Deploy a new ERC-20 (if needed) or reuse an existing mirrored token.
2. Configure `ManualPriceAdapter` (or a Chainlink adapter) with the asset’s feed ID.
3. Deploy an `EquityOracleAdapter` pointing to that price source.
4. Register it inside Floe’s `PriceOracle` and/or your lending market.

The only on-chain change for each asset is the adapter deployment; everything else (interest math, LTV, UI) is parameterized. This keeps the protocol flexible enough to tokenize any priceable off-chain asset, not just crypto-native tokens.***

