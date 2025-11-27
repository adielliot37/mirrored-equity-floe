## NVDA Lending Protocol

This document describes the single-collateral, single-debt market introduced for mirrored NVDA backed borrowing.

For a deep dive into mirrored equity tokenization and oracle flow, see `docs/MIRRORED_EQUITY.md`.

### Contract Overview

| Contract | Path | Purpose |
| --- | --- | --- |
| `MockUSDC` | `src/MockUSDC.sol` | Lightweight 6-decimal ERC20 used for lending/borrowing. |
| `NvdaLendingPool` | `src/NvdaLendingPool.sol` | Core pool that prices NVDA via the deployed `EquityOracleAdapter` and manages supply/borrow accounting. |

### Parameters

- **LTV:** 60% — max borrow capacity vs. USD value of NVDA posted.
- **Liquidation threshold:** 75% — once a borrower crosses this ratio they become liquidatable.
- **Liquidation bonus:** 5% of debt value, paid as discounted NVDA.
- **Interest model:** Linear 5% base APR + 45% slope that scales with utilization (`borrowed / supplied`). Lender APR = borrower APR × utilization × (1 - reserve factor).
- **Reserve factor:** 10% of interest routed to protocol reserves.
- **Withdrawals:** NVDA collateral cannot be withdrawn while any debt is outstanding; borrowers must repay mUSDC first.

These values mirror the guidance from Floe's November 13, 2025 changelog, where TVL is tracked off-chain and dynamic APRs are derived from utilization to balance borrower and lender incentives ([docs](https://floe-labs.gitbook.io/docs)).

### Accounting Model

- **Scaled balances:** Both deposits and debt are stored as scaled values that grow with indexes (`liquidityIndex`, `borrowIndex`). Indexes update linearly each block based on the instantaneous APR, so lenders accrue yield and borrowers accrue interest continuously.
- **Pricing:** NVDA collateral is valued from the already deployed `EquityOracleAdapter` (`latestRoundData` with 8 decimals). Values are normalized into 6-decimal USD (mUSDC) so that all limits, health factors, and max borrow calculations share one unit.
- **Health Factor:** `collateralUSD × 0.75 / debtUSD`. Above 1.0 = safe. Used both for withdrawals and liquidation eligibility.

### Liquidations

Liquidators can repay up to the full outstanding debt for unhealthy accounts. Repayments must be provided in mUSDC. NVDA seized = `repayAmount × 1.05 / price`, capped by the borrower's collateral balance.

### UI / UX

- The `apps/web` Vite app surfaces live APRs, utilization, NVDA price, collateral, max borrowable amount, and health factor.
- Borrowers now start by entering the mUSDC amount + duration they want; the UI reads the live oracle price and displays the required NVDA collateral (60% LTV) via the same math as the on-chain `collateralRequired()` view.
- Borrow action buttons stay disabled until the required NVDA has been deposited and approved, preventing MetaMask “source not authorized” reverts caused by missing allowances.
- Duration presets (7 / 30 / 90 days) still act as intent metadata; repayments can still happen at any time but must be in mUSDC.
- Lenders can deposit or withdraw at any time; supply APR immediately reflects utilization, aligning with Floe's guidance to make APY responsive to pool depth.

### Deployment

1. Deploy `MockUSDC`.
2. Deploy `MockUSDC` separately via `forge script script/DeployMockUSDC.s.sol --broadcast`.
3. Deploy `NvdaLendingPool` via `forge script script/DeployNvdaLendingPool.s.sol --broadcast` supplying env vars:
   - `NVDA_TOKEN = 0x370627bb90F37907bE2293a60d77e4938b35FAbA`
   - `USDC_TOKEN = <MockUSDC address>`
   - `NVDA_ORACLE = 0xC0bC892cbA12632055B7961639E3bB6A3253B17c`
3. Fund initial liquidity (optional) by depositing mUSDC as a lender.
4. Update `apps/web/env.example` with the new addresses and `VITE_RPC_URL`.

### Local Dev Workflow

```bash
# Terminal 1 – smart contracts
forge test

# Terminal 2 – UI
cd apps/web
npm install
npm run dev
```

The Vite UI expects a browser wallet on Base Sepolia. Update `.env.local` (copy from `env.example`) with RPC + contract addresses after deployment. 

