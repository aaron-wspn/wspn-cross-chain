import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { holesky, mainnet, polygon, polygonAmoy, sepolia } from "wagmi/chains";

/**
 * Even with SSR enabled, environment variables used in client-side code must be prefixed with NEXT_PUBLIC_ because
 * this code will eventually run in the browser. The chains array is used both during SSR and client-side rendering,
 * so Next.js needs to expose this variable to the client bundle.
 */
export const config = getDefaultConfig({
  appName: "RainbowKit App",
  projectId: "YOUR_PROJECT_ID",
  chains: [
    mainnet,
    polygon,
    // optimism,
    // arbitrum,
    // base,
    ...(process.env.NEXT_PUBLIC_ENABLE_TESTNETS === "true"
      ? [holesky, polygonAmoy, sepolia]
      : []),
  ],
  ssr: true,
});
