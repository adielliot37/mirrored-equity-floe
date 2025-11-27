import { formatUnits as formatUnitsViem, parseUnits as parseUnitsViem } from "viem";

export function formatMoney(value: bigint, decimals = 6, precision = 2) {
  const formatted = Number(formatUnitsViem(value, decimals));
  return `$${formatted.toLocaleString(undefined, {
    maximumFractionDigits: precision,
    minimumFractionDigits: precision,
  })}`;
}

export function formatToken(value: bigint, decimals: number, precision = 4) {
  const num = Number(formatUnitsViem(value, decimals));
  return num.toLocaleString(undefined, {
    maximumFractionDigits: precision,
  });
}

export function formatPercent(valueWad: bigint, precision = 2) {
  const asFloat = Number(valueWad) / 1e18;
  return `${(asFloat * 100).toFixed(precision)}%`;
}

export function parseInput(value: string, decimals: number) {
  if (!value || Number(value) === 0) return 0n;
  return parseUnitsViem(value, decimals);
}

const HF_INFINITY_THRESHOLD = 1_000_000n * 10n ** 18n;

export function formatHealthFactor(value?: bigint) {
  if (value === undefined) return "--";
  if (value === 0n) return "∞";
  if (value >= HF_INFINITY_THRESHOLD) return "∞";
  const asNumber = Number(formatUnitsViem(value, 18));
  if (!Number.isFinite(asNumber)) return "∞";
  return asNumber >= 10 ? asNumber.toFixed(1) : asNumber.toFixed(2);
}

