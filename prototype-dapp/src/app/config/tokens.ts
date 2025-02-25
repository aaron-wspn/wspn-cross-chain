import { Address } from "viem";
import {
  mainnet,
  polygon,
  optimism,
  arbitrum,
  base,
  sepolia,
  holesky,
} from "wagmi/chains";

// Type definitions
type TokenConfig = {
  address: Address;
  decimals?: number;
  symbol?: string;
  name?: string;
};

type ChainTokenConfig = {
  [chainId: number]: {
    tokens: {
      [tokenSymbol: string]: TokenConfig;
    };
  };
};

// Token configuration per chain
export const tokenConfig: ChainTokenConfig = {
  [sepolia.id]: {
    tokens: {
      WUSD: {
        address: "0xaF16E77FbF7Ca7649387124E7d4061c7e95206A1",
        symbol: "WUSD",
        name: "Wrapped USD",
      },
    },
  },
  [holesky.id]: {
    tokens: {
      WUSD: {
        address: "0xDdCb87d9CAdB7a030f35cD890Be49F7554473638",
        symbol: "WUSD",
        name: "Wrapped USD",
      },
    },
  },
  [mainnet.id]: {
    tokens: {
      WUSD: {
        address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
        symbol: "WUSD",
        name: "Wrapped USD",
      },
    },
    // Add as many chains as there are in wagmi.ts
  },
};

// Helper functions
export function getTokenAddress(
  chainId: number,
  symbol: string
): Address | undefined {
  return tokenConfig[chainId]?.tokens[symbol]?.address;
}

export function getTokenConfig(
  chainId: number,
  symbol: string
): TokenConfig | undefined {
  return tokenConfig[chainId]?.tokens[symbol];
}

// You can add more helper functions as needed
