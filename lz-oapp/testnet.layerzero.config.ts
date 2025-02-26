import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

/**
 *  The token address for the adapter should be defined in hardhat.config. This will be used in deployment. For example:
 *
 *  ```
 *    sepolia: {
 *         eid: EndpointId.SEPOLIA_V2_TESTNET,
 *         url: process.env.RPC_URL_SEPOLIA || 'https://rpc.sepolia.org/',
 *         accounts,
 *         oft-adapter: {
 *             tokenAddress: '0x0', // Set the token address for the OFT adapter
 *         },
 *     },
 *  ```
 */
const sepoliaContract: OmniPointHardhat = {
    eid: EndpointId.SEPOLIA_V2_TESTNET,
    contractName: 'WusdOFTAdapter',
}

const holeskyContract: OmniPointHardhat = {
    eid: EndpointId.HOLESKY_V2_TESTNET,
    contractName: 'WusdOFTAdapter',
}

const config: OAppOmniGraphHardhat = {
    contracts: [
        {
            contract: holeskyContract,
        },
        {
            contract: sepoliaContract,
        },
    ],
    connections: [
        {
            from: holeskyContract,
            to: sepoliaContract,
        },
        {
            from: sepoliaContract,
            to: holeskyContract,
        },
    ],
}

export default config
