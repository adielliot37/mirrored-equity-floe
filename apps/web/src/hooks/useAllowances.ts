import { useQuery } from "@tanstack/react-query";
import { readContracts } from "@wagmi/core";
import type { Address } from "viem";

import { wagmiConfig } from "../lib/wagmi";
import { contracts } from "../config/contracts";
import { erc20Abi } from "../abi/erc20";

type AllowanceResult = {
  nvda: bigint;
  usdc: bigint;
};

export function useAllowances(account?: Address) {
  return useQuery<AllowanceResult>({
    queryKey: ["allowances", account],
    enabled: Boolean(account && account !== "0x0000000000000000000000000000000000000000"),
    initialData: { nvda: 0n, usdc: 0n },
    queryFn: async () => {
      if (!account) return { nvda: 0n, usdc: 0n };
      const results = await readContracts(wagmiConfig, {
        contracts: [
          {
            address: contracts.nvda,
            abi: erc20Abi,
            functionName: "allowance",
            args: [account, contracts.pool],
          },
          {
            address: contracts.usdc,
            abi: erc20Abi,
            functionName: "allowance",
            args: [account, contracts.pool],
          },
        ],
      });

      return {
        nvda: (results[0].status === "success" ? results[0].result : 0n) as bigint,
        usdc: (results[1].status === "success" ? results[1].result : 0n) as bigint,
      };
    },
    refetchInterval: 15_000,
  });
}

