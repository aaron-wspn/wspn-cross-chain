// Get the environment configuration from .env file
//
// To make use of automatic environment setup:
// - Duplicate .env.example file and name it .env
// - Fill in the environment variables
import dotenv from 'dotenv'

import 'hardhat-deploy'
import 'hardhat-contract-sizer'
import '@nomiclabs/hardhat-ethers'
// import '@nomicfoundation/hardhat-ethers' // newer version but not compatible with @layerzerolabs/devtools-evm-hardhat
import '@typechain/hardhat'
import '@layerzerolabs/toolbox-hardhat'
import '@nomicfoundation/hardhat-chai-matchers'
import { HardhatUserConfig, HttpNetworkAccountsUserConfig } from 'hardhat/types'
import 'solidity-coverage'
import '@fireblocks/hardhat-fireblocks'
import { FireblocksProviderConfig } from '@fireblocks/fireblocks-web3-provider'

import { EndpointId } from '@layerzerolabs/lz-definitions'

import './type-extensions'

dotenv.config({ path: 'local.env' })

// Set your preferred authentication method
//
// If you prefer using a mnemonic, set a MNEMONIC environment variable
// to a valid mnemonic
const MNEMONIC = process.env.MNEMONIC

// If you prefer to be authenticated using a private key, set a PRIVATE_KEY environment variable
const PRIVATE_KEY = process.env.PRIVATE_KEY

if (process.env.FIREBLOCKS_VAULT_ACCOUNT_IDS) {
    console.info('Using Fireblocks accounts to operate')
}
const fireblocksProviderGlobalConfig: FireblocksProviderConfig = {
    privateKey: process.env.FIREBLOCKS_API_PRIVATE_KEY_PATH!,
    apiKey: process.env.FIREBLOCKS_API_KEY!,
    vaultAccountIds: process.env.FIREBLOCKS_VAULT_ACCOUNT_IDS,
}

const accounts: HttpNetworkAccountsUserConfig | undefined = MNEMONIC
    ? { mnemonic: MNEMONIC }
    : PRIVATE_KEY
      ? [PRIVATE_KEY]
      : undefined

if (accounts == null || !process.env.FIREBLOCKS_API_KEY) {
    console.warn(
        'Could not find MNEMONIC or PRIVATE_KEY environment variables. It will not be possible to execute transactions in your example.'
    )
}

const config: HardhatUserConfig = {
    paths: {
        cache: 'cache/hardhat',
    },
    solidity: {
        compilers: [
            {
                version: '0.8.27',
                settings: {
                    viaIR: true,
                    optimizer: {
                        enabled: true,
                        runs: 2000,
                        details: {
                            yulDetails: {
                                optimizerSteps: 'u',
                            },
                        },
                    },
                },
            },
        ],
    },
    typechain: {
        outDir: 'typechain-types',
        target: 'ethers-v5',
    },
    networks: {
        hardhat: {
            // Need this for testing because TestHelperOz5.sol is exceeding the compiled contract size limit
            allowUnlimitedContractSize: true,
        },
        // 'amoy-testnet': {
        //     eid: EndpointId.AMOY_V2_TESTNET,
        //     url: process.env.RPC_URL_AMOY || 'https://polygon-amoy-bor-rpc.publicnode.com',
        //     accounts,
        // },
        // 'avalanche-testnet': {
        //     eid: EndpointId.AVALANCHE_V2_TESTNET,
        //     url: process.env.RPC_URL_FUJI || 'https://rpc.ankr.com/avalanche_fuji',
        //     accounts,
        // },
        'holesky-testnet': {
            eid: EndpointId.HOLESKY_V2_TESTNET,
            url: process.env.RPC_URL_HOLESKY || 'https://ethereum-holesky-rpc.publicnode.com',
            accounts,
            oftAdapter: {
                tokenAddress: '0xDdCb87d9CAdB7a030f35cD890Be49F7554473638', // Set the token address for the OFT adapter
            },
        },
        'sepolia-testnet': {
            eid: EndpointId.SEPOLIA_V2_TESTNET,
            url: process.env.RPC_URL_SEPOLIA || 'https://eth-sepolia.public.blastapi.io',
            // accounts,
            fireblocks: fireblocksProviderGlobalConfig,
            oftAdapter: {
                tokenAddress: '0xaF16E77FbF7Ca7649387124E7d4061c7e95206A1', // Set the token address for the OFT adapter
            },
        },
    },
    namedAccounts: {
        deployer: {
            // default: 0, // wallet address of index[0] in fireblocks vault account list
            default: process.env.DEPLOYER_ADDRESS || 0,
        },
        tokenDefaultAdmin: {
            // default: 1, // wallet address of index[1] in fireblocks vault account list
            default: process.env.TOKEN_DEFAULT_ADMIN_ADDRESS || 1,
        },
    },
    mocha: {
        timeout: 60_000 * 5, // 5 minutes
    },
}

export default config
