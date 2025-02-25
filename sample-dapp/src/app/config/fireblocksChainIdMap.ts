// Map Fireblocks asset IDs to EVM chain IDs
export const fireblocksAssetIdToChainId: { [key: string]: number } = {
  ETH: 1, // Ethereum Mainnet
  MATIC: 137, // Polygon Mainnet
  ETH_TEST5: 11155111, // Sepolia
  ETH_TEST6: 17000, // Holesky
  AMOY_POLYGON_TEST: 80002, // Polygon Amoy
};

// Reverse mapping from chain IDs to Fireblocks asset IDs
export const chainIdToFireblocksAssetId: { [key: number]: string } =
  Object.entries(fireblocksAssetIdToChainId).reduce(
    (acc, [assetId, chainId]) => ({
      ...acc,
      [chainId]: assetId,
    }),
    {}
  );
