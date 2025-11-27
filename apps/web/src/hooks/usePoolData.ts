import { useQuery } from "@tanstack/react-query";
import { readContract } from "@wagmi/core";
import { zeroAddress } from "viem";
import { wagmiConfig } from "../lib/wagmi";
import { contracts } from "../config/contracts";
import { nvdaLendingPoolAbi } from "../abi/NvdaLendingPool";
import { aggregatorAbi } from "../abi/chainlinkAggregator";

export function usePoolData(account?: `0x${string}`) {
  return useQuery({
    queryKey: ["pool-data", account],
    queryFn: async () => {
      const user = account ?? zeroAddress;
      const [
        rates,
        snapshot,
        borrowerPosition,
        lenderPosition,
        poolStats,
        price,
        priceDecimals,
      ] = await Promise.all([
        readContract(wagmiConfig, {
          address: contracts.pool,
          abi: nvdaLendingPoolAbi,
          functionName: "getRates",
        }),
        readContract(wagmiConfig, {
          address: contracts.pool,
          abi: nvdaLendingPoolAbi,
          functionName: "getUserSnapshot",
          args: [user],
        }),
        readContract(wagmiConfig, {
          address: contracts.pool,
          abi: nvdaLendingPoolAbi,
          functionName: "getBorrowerPosition",
          args: [user],
        }),
        readContract(wagmiConfig, {
          address: contracts.pool,
          abi: nvdaLendingPoolAbi,
          functionName: "getLenderPosition",
          args: [user],
        }),
        readContract(wagmiConfig, {
          address: contracts.pool,
          abi: nvdaLendingPoolAbi,
          functionName: "getPoolStats",
        }),
        readContract(wagmiConfig, {
          address: contracts.oracle,
          abi: aggregatorAbi,
          functionName: "latestAnswer",
        }),
        readContract(wagmiConfig, {
          address: contracts.oracle,
          abi: aggregatorAbi,
          functionName: "decimals",
        }),
      ]);

      const [
        collateralNVDA,
        collateralUSD,
        debtUSDC,
        maxBorrowUSDC,
        healthFactor,
        lastBorrowTimestamp,
        durationSeconds,
      ] = snapshot as readonly [bigint, bigint, bigint, bigint, bigint, number, number];

      const priceRaw = price as bigint;
      const priceDec = priceDecimals as number;

      const borrowerTuple = borrowerPosition as readonly [bigint, bigint, bigint, bigint, bigint];
      const lenderTuple = lenderPosition as readonly [bigint, bigint, bigint];
      const poolTuple = poolStats as readonly [bigint, bigint, bigint];

      return {
        rates: {
          utilization: (rates as readonly [bigint, bigint, bigint])[0],
          borrowAPR: (rates as readonly [bigint, bigint, bigint])[1],
          supplyAPR: (rates as readonly [bigint, bigint, bigint])[2],
        },
        snapshot: {
          collateralNVDA,
          collateralUSD,
          debtUSDC,
          maxBorrowUSDC,
          healthFactor,
          lastBorrowTimestamp,
          durationSeconds,
        },
        borrower: {
          debtUSDC: borrowerTuple[0],
          principalUSDC: borrowerTuple[1],
          interestUSDC: borrowerTuple[2],
          maxBorrowUSDC: borrowerTuple[3],
          healthFactor: borrowerTuple[4],
        },
        lender: {
          balance: lenderTuple[0],
          principal: lenderTuple[1],
          interest: lenderTuple[2],
        },
        pool: {
          deposits: poolTuple[0],
          debt: poolTuple[1],
          liquidity: poolTuple[2],
        },
        price: {
          formatted: formatOraclePrice(priceRaw, priceDec),
          raw: priceRaw,
          decimals: priceDec,
        },
      };
    },
    staleTime: 10_000,
    refetchInterval: 15_000,
  });
}

function formatOraclePrice(raw: bigint, decimals: number) {
  const scale = 10 ** decimals;
  return Number(raw) / scale;
}

