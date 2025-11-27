/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_POOL_ADDRESS?: string;
  readonly VITE_NVDA_ADDRESS?: string;
  readonly VITE_USDC_ADDRESS?: string;
  readonly VITE_NVDA_ORACLE?: string;
  readonly VITE_RPC_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

