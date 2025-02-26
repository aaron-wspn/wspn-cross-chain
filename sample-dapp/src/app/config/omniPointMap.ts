import { EndpointId } from "@layerzerolabs/lz-definitions";
import { OmniPoint } from "@layerzerolabs/devtools";

// Map chain IDs to their corresponding OmniPoint configurations
export const chainIdToOmniPoint: { [key: number]: OmniPoint } = {
  1: {
    eid: EndpointId.ETHEREUM_V2_MAINNET, // Ethereum Mainnet
    address: "",
  },
  137: {
    eid: EndpointId.POLYGON_V2_MAINNET, // Polygon Mainnet
    address: "",
  },
  11155111: {
    eid: EndpointId.SEPOLIA_V2_TESTNET, // Sepolia
    address: "0x25086D265cD6a9db4238FEFdA08696b2dCf3B827",
  },
  17000: {
    eid: EndpointId.HOLESKY_V2_TESTNET, // Holesky
    address: "0x90DB49A71Bd8B52A4c9F06d17C45773709D6Bf8f",
  },
  80002: {
    eid: EndpointId.AMOY_V2_TESTNET, // Polygon Amoy
    address: "",
  },
};
