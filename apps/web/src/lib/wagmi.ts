import { createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";
import { baseSepolia } from "wagmi/chains";

const rpcUrl = import.meta.env.VITE_RPC_URL ?? baseSepolia.rpcUrls.default.http[0];

export const appChain = baseSepolia;

export const wagmiConfig = createConfig({
  chains: [appChain],
  transports: {
    [appChain.id]: http(rpcUrl),
  },
  connectors: [
    injected({
      shimDisconnect: true,
    }),
  ],
});

