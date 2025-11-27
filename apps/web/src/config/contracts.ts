import type { Address } from "viem";
import { zeroAddress } from "viem";

function getAddress(envKey: string): Address {
  const value = import.meta.env[envKey as keyof ImportMetaEnv];
  return value && value !== "" ? (value as Address) : zeroAddress;
}

export const contracts = {
  pool: getAddress("VITE_POOL_ADDRESS"),
  nvda: getAddress("VITE_NVDA_ADDRESS"),
  usdc: getAddress("VITE_USDC_ADDRESS"),
  oracle: getAddress("VITE_NVDA_ORACLE"),
};

export const tokenMeta = {
  nvda: { symbol: "NVDA", decimals: 18 },
  usdc: { symbol: "mUSDC", decimals: 6 },
};

