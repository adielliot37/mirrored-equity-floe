import { useMemo, useState } from "react";
import { useAccount, useConnect, useDisconnect, useWriteContract } from "wagmi";
import { usePoolData } from "./hooks/usePoolData";
import { useAllowances } from "./hooks/useAllowances";
import { MetricCard } from "./components/MetricCard";
import { formatMoney, formatPercent, formatToken, parseInput, formatHealthFactor } from "./lib/format";
import { contracts, tokenMeta } from "./config/contracts";
import { nvdaLendingPoolAbi } from "./abi/NvdaLendingPool";
import { erc20Abi } from "./abi/erc20";

const MAX_UINT256 = (1n << 256n) - 1n;

function App() {
  const { address, isConnected } = useAccount();
  const { connectors, connect, status: connectStatus } = useConnect();
  const { disconnect } = useDisconnect();
  const { writeContractAsync, isPending } = useWriteContract();
  const { data, isLoading, refetch } = usePoolData(address as `0x${string}` | undefined);
  const {
    data: allowances = { nvda: 0n, usdc: 0n },
    refetch: refetchAllowances,
  } = useAllowances(address as `0x${string}` | undefined);

  const [withdrawCollateralAmount, setWithdrawCollateralAmount] = useState("");
  const [depositUSDCAmount, setDepositUSDCAmount] = useState("");
  const [withdrawUSDCAmount, setWithdrawUSDCAmount] = useState("");
  const [borrowDuration, setBorrowDuration] = useState(30);
  const [repayAmount, setRepayAmount] = useState("");
  const [plannedBorrowAmount, setPlannedBorrowAmount] = useState("");

  const parsedDepositUsdcAmount = useMemo(
    () => parseInput(depositUSDCAmount, tokenMeta.usdc.decimals),
    [depositUSDCAmount],
  );
  const parsedRepayAmount = useMemo(
    () => parseInput(repayAmount, tokenMeta.usdc.decimals),
    [repayAmount],
  );
  const plannedBorrowAmountBig = useMemo(
    () => parseInput(plannedBorrowAmount, tokenMeta.usdc.decimals),
    [plannedBorrowAmount],
  );
  const planRequirements = useMemo(() => {
    if (!data || plannedBorrowAmountBig === 0n) {
      return { collateralUsd: 0n, collateralNvda: 0n };
    }
    const collateralUsd = divUp(
      plannedBorrowAmountBig * BigInt(10_000),
      BigInt(6_000),
    );
    const oracleDecimals = BigInt(data.price.decimals);
    const usdInOracleUnits =
      oracleDecimals >= 6
        ? collateralUsd * 10n ** (oracleDecimals - 6n)
        : collateralUsd / 10n ** (6n - oracleDecimals);
    if (data.price.raw == null || data.price.raw === 0n) {
      return { collateralUsd, collateralNvda: 0n };
    }
    const collateralNvda = divUp(
      usdInOracleUnits * 10n ** BigInt(tokenMeta.nvda.decimals),
      data.price.raw,
    );
    return { collateralUsd, collateralNvda };
  }, [data, plannedBorrowAmountBig]);
  const borrowerInfo = data?.borrower;
  const lenderInfo = data?.lender;
  const poolInfo = data?.pool;
  const requiredCollateral = planRequirements.collateralNvda;
  const currentCollateral = data?.snapshot.collateralNVDA ?? 0n;
  const missingCollateral = requiredCollateral > currentCollateral ? requiredCollateral - currentCollateral : 0n;
  const hasSufficientCollateral = missingCollateral === 0n && plannedBorrowAmountBig > 0n;
  const hasDebt = (borrowerInfo?.debtUSDC ?? 0n) > 0n;
  const priceFormatted = data?.price?.formatted;
  const requiredCollateralDisplay =
    requiredCollateral > 0n
      ? `${formatToken(requiredCollateral, tokenMeta.nvda.decimals)} NVDA`
      : "--";
  const missingCollateralDisplay =
    missingCollateral > 0n ? `${formatToken(missingCollateral, tokenMeta.nvda.decimals)} NVDA` : "0 NVDA";
  const requiredCollateralUsdDisplay =
    planRequirements.collateralUsd > 0n
      ? formatMoney(planRequirements.collateralUsd, tokenMeta.usdc.decimals)
      : "--";
  const needsNvdaApproval = missingCollateral > 0n && allowances.nvda < missingCollateral;
  const needsUsdcApprovalForDeposit =
    parsedDepositUsdcAmount > 0n && allowances.usdc < parsedDepositUsdcAmount;
  const needsUsdcApprovalForRepay =
    parsedRepayAmount > 0n && allowances.usdc < parsedRepayAmount;
  const exceedsUserCap =
    borrowerInfo && plannedBorrowAmountBig > borrowerInfo.maxBorrowUSDC;
  const exceedsPoolCap =
    poolInfo && plannedBorrowAmountBig > poolInfo.liquidity;
  const borrowDisabled =
    !isConnected ||
    isPending ||
    plannedBorrowAmountBig === 0n ||
    missingCollateral > 0n ||
    Boolean(exceedsUserCap) ||
    Boolean(exceedsPoolCap);
  const borrowHelper = (() => {
    if (!plannedBorrowAmount) return "Enter a borrow amount.";
    if (missingCollateral > 0n) return "Stake the required NVDA before borrowing.";
    if (exceedsUserCap) return "Above your collateral limit.";
    if (exceedsPoolCap) return "Above pool liquidity.";
    return undefined;
  })();

  const metrics = useMemo(() => {
    if (!data) {
      return null;
    }
    const {
      rates,
      snapshot: { collateralNVDA, collateralUSD },
      price,
      borrower,
      lender,
      pool,
    } = data;

    return {
      supplyApr: formatPercent(rates.supplyAPR),
      borrowApr: formatPercent(rates.borrowAPR),
      utilization: `${(Number(rates.utilization) / 1e16).toFixed(2)}%`,
      collateralUsd: formatMoney(collateralUSD),
      collateralNvda: `${formatToken(collateralNVDA, tokenMeta.nvda.decimals)} NVDA`,
      repayTotal: formatMoney(borrower.debtUSDC),
      borrowerInterest: formatMoney(borrower.interestUSDC, tokenMeta.usdc.decimals, 4),
      lenderBalance: formatMoney(lender.balance),
      lenderPrincipal: formatMoney(lender.principal),
      lenderInterest: formatMoney(lender.interest, tokenMeta.usdc.decimals, 4),
      maxBorrowUsd: formatMoney(borrower.maxBorrowUSDC),
      poolLiquidity: formatMoney(pool.liquidity),
      poolDeposits: formatMoney(pool.deposits),
      poolDebt: formatMoney(pool.debt),
      healthFactor: formatHealthFactor(borrower.healthFactor),
      nvdaPrice: `$${price.formatted.toFixed(2)}`,
    };
  }, [data]);

  const primaryConnector = connectors[0];

  const handleTx = async (fn: () => Promise<unknown>) => {
    await fn();
    await refetch();
  };

  const handleApprove = async (token: "nvda" | "usdc") => {
    const tokenAddress = token === "nvda" ? contracts.nvda : contracts.usdc;
    await handleTx(() =>
      writeContractAsync({
        address: tokenAddress,
        abi: erc20Abi,
        functionName: "approve",
        args: [contracts.pool, MAX_UINT256],
      }),
    );
    await refetchAllowances();
  };

  const handleDepositCollateral = async () => {
    const amount = missingCollateral;
    if (plannedBorrowAmountBig === 0n) {
      alert("Enter the mUSDC amount you plan to borrow first.");
      return;
    }
    if (amount === 0n) {
      alert("You already have enough NVDA posted for this borrow plan.");
      return;
    }
    if (allowances.nvda < amount) {
      alert("Approve NVDA spending cap before depositing.");
      return;
    }
    await handleTx(() =>
      writeContractAsync({
        address: contracts.pool,
        abi: nvdaLendingPoolAbi,
        functionName: "depositCollateral",
        args: [amount],
      }),
    );
    await refetchAllowances();
  };

  const handleWithdrawCollateral = async () => {
    const amount = parseInput(withdrawCollateralAmount, tokenMeta.nvda.decimals);
    await handleTx(() =>
      writeContractAsync({
        address: contracts.pool,
        abi: nvdaLendingPoolAbi,
        functionName: "withdrawCollateral",
        args: [amount],
      }),
    );
    setWithdrawCollateralAmount("");
  };

  const handleDepositUSDC = async () => {
    const amount = parseInput(depositUSDCAmount, tokenMeta.usdc.decimals);
    if (amount === 0n) {
      alert("Enter an amount greater than zero.");
      return;
    }
    if (allowances.usdc < amount) {
      alert("Approve mUSDC spending cap before depositing.");
      return;
    }
    await handleTx(() =>
      writeContractAsync({
        address: contracts.pool,
        abi: nvdaLendingPoolAbi,
        functionName: "depositUSDC",
        args: [amount],
      }),
    );
    setDepositUSDCAmount("");
  };

  const handleWithdrawUSDC = async () => {
    const amount = parseInput(withdrawUSDCAmount, tokenMeta.usdc.decimals);
    await handleTx(() =>
      writeContractAsync({
        address: contracts.pool,
        abi: nvdaLendingPoolAbi,
        functionName: "withdrawUSDC",
        args: [amount],
      }),
    );
    setWithdrawUSDCAmount("");
  };

  const handleBorrow = async () => {
    const amount = plannedBorrowAmountBig;
    if (amount === 0n) {
      alert("Enter the mUSDC amount you plan to borrow.");
      return;
    }
    if (!hasSufficientCollateral) {
      alert("Deposit the required NVDA collateral first.");
      return;
    }
    if (exceedsUserCap) {
      alert("Borrow amount exceeds your collateral limit.");
      return;
    }
    if (exceedsPoolCap) {
      alert("Borrow amount exceeds pool liquidity.");
      return;
    }
    const durationSeconds = BigInt(borrowDuration * 24 * 60 * 60);
    await handleTx(() =>
      writeContractAsync({
        address: contracts.pool,
        abi: nvdaLendingPoolAbi,
        functionName: "borrow",
        args: [amount, durationSeconds],
      }),
    );
  };

  const handleRepay = async () => {
    const amount = parseInput(repayAmount, tokenMeta.usdc.decimals);
    if (amount === 0n) {
      alert("Enter an amount greater than zero.");
      return;
    }
    if (allowances.usdc < amount) {
      alert("Approve mUSDC spending cap before repaying.");
      return;
    }
    await handleTx(() =>
      writeContractAsync({
        address: contracts.pool,
        abi: nvdaLendingPoolAbi,
        functionName: "repay",
        args: [amount],
      }),
    );
    setRepayAmount("");
  };

  return (
    <main className="mx-auto flex min-h-screen max-w-6xl flex-col gap-10 px-6 py-8 text-white">
      <header className="flex flex-col items-start justify-between gap-4 md:flex-row md:items-center">
        <div>
          <p className="text-sm uppercase tracking-[0.3em] text-brand-100">Floe Markets</p>
          <h1 className="mt-2 text-4xl font-semibold">Borrow USDC with NVDA collateral</h1>
          <p className="mt-1 text-slate-300">
            Stake mirrored NVDA, access dynamic USDC liquidity, and monitor live earnings.
          </p>
        </div>
        <div className="flex gap-3">
          {isConnected ? (
            <button
              className="rounded-full border border-white/20 px-4 py-2 text-sm"
              onClick={() => disconnect()}
            >
              {address?.slice(0, 6)}…{address?.slice(-4)} · Disconnect
            </button>
          ) : (
            <button
              className="rounded-full bg-brand-500 px-4 py-2 text-sm font-semibold text-white"
              onClick={() => primaryConnector && connect({ connector: primaryConnector })}
              disabled={connectStatus === "pending"}
            >
              {connectStatus === "pending" ? "Connecting…" : "Connect Wallet"}
            </button>
          )}
        </div>
      </header>

      <section className="grid gap-4 md:grid-cols-3">
        <MetricCard label="NVDA Spot" value={metrics?.nvdaPrice ?? "--"} hint="Oracle powered price (8dp)" />
        <MetricCard label="Borrow APR" value={metrics?.borrowApr ?? "--"} hint="Utilization-adjusted" />
        <MetricCard label="Supply APR" value={metrics?.supplyApr ?? "--"} hint="Live lender earnings" />
        <MetricCard label="Utilization" value={metrics?.utilization ?? "--"} hint="Borrowed vs available" />
        <MetricCard label="Pool Liquidity" value={metrics?.poolLiquidity ?? "--"} hint="Sets max borrow cap" />
        <MetricCard label="Pool Debt" value={metrics?.poolDebt ?? "--"} hint="Outstanding loans" />
        <MetricCard label="Pool Deposits" value={metrics?.poolDeposits ?? "--"} hint="Supplied capital" />
        <MetricCard label="Your Collateral" value={metrics?.collateralNvda ?? "--"} hint={metrics?.collateralUsd} />
        <MetricCard
          label="Your Borrow Cap"
          value={metrics?.maxBorrowUsd ?? "--"}
          hint="Limited by collateral & pool liquidity"
        />
        <MetricCard
          label="Repay Now"
          value={metrics?.repayTotal ?? "--"}
          hint={`Interest accrued: ${metrics?.borrowerInterest ?? "--"}`}
        />
        <MetricCard label="Health Factor" value={metrics?.healthFactor ?? "--"} hint=">1.0 stays safe" />
        <MetricCard
          label="Lender Balance"
          value={metrics?.lenderBalance ?? "--"}
          hint={`Principal: ${metrics?.lenderPrincipal ?? "--"}`}
        />
        <MetricCard label="Lender Interest" value={metrics?.lenderInterest ?? "--"} hint="Net yield earned" />
      </section>

      <div className="grid gap-6 lg:grid-cols-2">
        <section className="rounded-3xl border border-white/10 bg-white/5 p-6 backdrop-blur">
          <h2 className="text-xl font-semibold">Borrower controls</h2>
          <p className="text-sm text-slate-300">Stake NVDA, borrow USDC, and keep an eye on your health factor.</p>

          <div className="mt-6 space-y-4">
            <div className="rounded-2xl border border-white/10 p-4">
              <p className="text-sm text-slate-200">Plan your borrow</p>
              <p className="text-xs text-slate-400">
                Choose how much mUSDC you want and we’ll compute the NVDA you must stake (60% LTV).
              </p>
              <div className="mt-4 space-y-3">
                <label className="text-xs uppercase tracking-wide text-slate-400">Desired mUSDC</label>
                <input
                  className="w-full rounded-2xl border border-white/20 bg-transparent px-4 py-2 text-white outline-none"
                  value={plannedBorrowAmount}
                  onChange={(e) => {
                    setPlannedBorrowAmount(e.target.value);
                  }}
                  placeholder="0.0"
                  type="number"
                  min="0"
                />
                <div className="flex flex-wrap gap-2">
                  {[7, 30, 90].map((days) => (
                    <button
                      key={days}
                      className={`rounded-full px-3 py-1 text-xs ${borrowDuration === days ? "bg-brand-500 text-white" : "bg-white/10 text-slate-300"}`}
                      onClick={() => setBorrowDuration(days)}
                    >
                      {days}d
                    </button>
                  ))}
                </div>
              </div>
              <div className="mt-4 grid gap-3 sm:grid-cols-2">
                <div>
                  <p className="text-xs text-slate-400">Required NVDA</p>
                  <p className="text-xl font-semibold text-white">{requiredCollateralDisplay}</p>
                </div>
                <div>
                  <p className="text-xs text-slate-400">Collateral USD</p>
                  <p className="text-xl font-semibold text-white">{requiredCollateralUsdDisplay}</p>
                </div>
              </div>
              <div className="mt-4 grid gap-3 sm:grid-cols-2">
                <div>
                  <p className="text-xs text-slate-400">Currently posted</p>
                  <p className="text-xl font-semibold text-white">
                    {formatToken(currentCollateral, tokenMeta.nvda.decimals)} NVDA
                  </p>
                </div>
                <div>
                  <p className="text-xs text-slate-400">Still needed</p>
                  <p className="text-xl font-semibold text-amber-300">{missingCollateralDisplay}</p>
                </div>
              </div>
              <p className="mt-2 text-xs text-slate-500">
                NVDA price ${priceFormatted !== undefined ? priceFormatted.toFixed(2) : "--"} · Pool liquidity{" "}
                {poolInfo ? formatMoney(poolInfo.liquidity) : "--"}
              </p>
              <button
                className="mt-4 w-full rounded-2xl bg-brand-500 px-4 py-2 font-semibold text-white disabled:cursor-not-allowed disabled:bg-white/10"
                onClick={handleDepositCollateral}
                disabled={
                  !isConnected ||
                  isPending ||
                  plannedBorrowAmountBig === 0n ||
                  missingCollateral === 0n ||
                  needsNvdaApproval
                }
              >
                Deposit required NVDA
              </button>
              {plannedBorrowAmountBig === 0n ? (
                <p className="mt-2 text-xs text-slate-400">Enter the borrow amount above to see collateral needs.</p>
              ) : null}
              {needsNvdaApproval ? (
                <p className="mt-2 text-xs text-amber-300">Approve NVDA spending cap before depositing.</p>
              ) : null}
            </div>

            <ActionRow
              title="Withdraw NVDA"
              inputProps={{
                value: withdrawCollateralAmount,
                onChange: setWithdrawCollateralAmount,
                placeholder: "0.0",
              }}
              actionLabel="Withdraw"
              helperText={hasDebt ? "Repay outstanding mUSDC before withdrawing NVDA." : undefined}
              disabled={!isConnected || isPending || !withdrawCollateralAmount || hasDebt}
              onAction={handleWithdrawCollateral}
            />

            <div className="rounded-2xl border border-white/10 p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-slate-300">Borrow mUSDC</p>
                  <p className="text-xs text-slate-400">
                    Duration {borrowDuration} days · Available up to {metrics?.maxBorrowUsd ?? "--"}
                  </p>
                </div>
              </div>
              <div className="mt-4 grid gap-3 sm:grid-cols-2">
                <div>
                  <p className="text-xs text-slate-400">Borrow amount</p>
                  <p className="text-xl font-semibold text-white">
                    {plannedBorrowAmount ? `${plannedBorrowAmount} mUSDC` : "--"}
                  </p>
                </div>
                <div>
                  <p className="text-xs text-slate-400">Collateral available</p>
                  <p className="text-xl font-semibold text-white">
                    {formatToken(data?.snapshot.collateralNVDA ?? 0n, tokenMeta.nvda.decimals)} NVDA
                  </p>
                </div>
              </div>
              <button
                className="mt-4 w-full rounded-2xl bg-brand-500 px-4 py-2 font-semibold disabled:cursor-not-allowed disabled:bg-white/10"
                disabled={borrowDisabled}
                onClick={handleBorrow}
              >
                Borrow selected amount
              </button>
              {borrowHelper ? <p className="mt-2 text-xs text-amber-300">{borrowHelper}</p> : null}
            </div>

            <ActionRow
              title="Repay mUSDC"
              subtitle="Repay principal + interest in mUSDC"
              inputProps={{
                value: repayAmount,
                onChange: setRepayAmount,
                placeholder: "0.0",
              }}
              actionLabel="Repay"
              helperText={
                needsUsdcApprovalForRepay ? "Approve mUSDC spending cap before repaying." : undefined
              }
              disabled={!isConnected || isPending || !repayAmount || needsUsdcApprovalForRepay}
              onAction={handleRepay}
            />

            <div className="rounded-2xl border border-white/10 p-4">
              <p className="text-sm text-slate-300">Repay overview</p>
              <div className="mt-3 grid gap-3 sm:grid-cols-2">
                <div>
                  <p className="text-xs text-slate-400">Outstanding total</p>
                  <p className="text-xl font-semibold text-white">{metrics?.repayTotal ?? "--"}</p>
                </div>
                <div>
                  <p className="text-xs text-slate-400">Interest so far</p>
                  <p className="text-xl font-semibold text-white">{metrics?.borrowerInterest ?? "--"}</p>
                </div>
              </div>
            </div>
          </div>

          <div className="mt-6 flex gap-3 text-sm text-slate-300">
            <button className="rounded-full border border-white/20 px-3 py-1" onClick={() => handleApprove("nvda")}>
              Approve NVDA
            </button>
            <button className="rounded-full border border-white/20 px-3 py-1" onClick={() => handleApprove("usdc")}>
              Approve mUSDC
            </button>
          </div>
        </section>

        <section className="rounded-3xl border border-white/10 bg-white/5 p-6 backdrop-blur">
          <h2 className="text-xl font-semibold">Lender controls</h2>
          <p className="text-sm text-slate-300">Deposit mUSDC, withdraw anytime, and watch yields flex with utilization.</p>

          <div className="mt-6 space-y-4">
            <ActionRow
              title="Supply mUSDC"
              subtitle="Earn the current dynamic APY"
              inputProps={{
                value: depositUSDCAmount,
                onChange: setDepositUSDCAmount,
                placeholder: "0.0",
              }}
              actionLabel="Deposit"
              helperText={
                needsUsdcApprovalForDeposit ? "Approve mUSDC spending cap before depositing." : undefined
              }
              disabled={
                !isConnected ||
                isPending ||
                !depositUSDCAmount ||
                needsUsdcApprovalForDeposit
              }
              onAction={handleDepositUSDC}
            />

            <ActionRow
              title="Withdraw mUSDC"
              subtitle="Instant when liquidity available"
              inputProps={{
                value: withdrawUSDCAmount,
                onChange: setWithdrawUSDCAmount,
                placeholder: "0.0",
              }}
              actionLabel="Withdraw"
              disabled={!isConnected || isPending || !withdrawUSDCAmount}
              onAction={handleWithdrawUSDC}
            />
          </div>

          <div className="mt-6 rounded-2xl border border-white/10 bg-black/30 p-4">
            <p className="text-sm text-slate-300">Live earnings</p>
            <h3 className="mt-2 text-3xl font-semibold text-white">{metrics?.lenderInterest ?? "--"}</h3>
            <p className="text-xs text-slate-400">
              Principal supplied: {metrics?.lenderPrincipal ?? "--"} · APY {metrics?.supplyApr ?? "--"}
            </p>
          </div>
        </section>
      </div>

      {isLoading ? <p className="text-center text-slate-400">Loading protocol data…</p> : null}
    </main>
  );
}

type ActionRowProps = {
  title: string;
  subtitle?: string;
  inputProps: {
    value: string;
    onChange: (value: string) => void;
    placeholder?: string;
  };
  actionLabel: string;
  disabled?: boolean;
  helperText?: string;
  onAction: () => Promise<void> | void;
};

function ActionRow({ title, subtitle, inputProps, actionLabel, disabled, helperText, onAction }: ActionRowProps) {
  return (
    <div className="rounded-2xl border border-white/10 p-4">
      <p className="text-sm text-slate-200">{title}</p>
      {subtitle ? <p className="text-xs text-slate-400">{subtitle}</p> : null}
      <div className="mt-3 flex gap-3">
        <input
          className="flex-1 rounded-2xl border border-white/20 bg-transparent px-4 py-2 text-white outline-none"
          value={inputProps.value}
          onChange={(e) => inputProps.onChange(e.target.value)}
          placeholder={inputProps.placeholder}
          type="number"
          min="0"
        />
        <button
          className="rounded-2xl bg-white/10 px-4 py-2 font-semibold text-white"
          disabled={disabled}
          onClick={() => onAction()}
        >
          {actionLabel}
        </button>
      </div>
      {helperText ? <p className="mt-2 text-xs text-amber-300">{helperText}</p> : null}
    </div>
  );
}

function divUp(value: bigint, divisor: bigint) {
  if (divisor === 0n) return 0n;
  return (value + divisor - 1n) / divisor;
}

export default App;

