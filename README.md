# WSPN Bridging

A cross-chain bridging solution for WUSD tokens using LayerZero's OFT (Omnichain Fungible Token) protocol.

## Getting started

### Prerequisite software

1. [Node.js](https://nodejs.org/en/download/)
2. [Yarn](https://yarnpkg.com/getting-started/install)
3. [Hardhat](https://hardhat.org/getting-started/)
4. [Foundry](https://getfoundry.sh/) (optional, for running tests)

### Prerequisites

- ERC20F tokens must be already deployed. For this, we can use the [Tokenization Engine](https://www.fireblocks.com/platforms/tokenization/)
- Access to Fireblocks account (for signing transactions when deploying to testnet/mainnet)

## Contract Architecture

The WSPN Bridging solution consists of the following components:

1. **WusdOFTAdapter**: A contract that manages (or adapts) an ERC20F token to
  provide OFT (Omnichain Fungible Token) functionality
   - Connects to LayerZero endpoints for cross-chain messaging
   - Manages token minting/burning during bridging
   - Implements role-based access control for operations
   - Handles authorization from the issuer (WSPN) for sending tokens across chains

1. **LayerZero Protocol**: Used for cross-chain communication
   - Provides messaging between different blockchains
   - Manages message verification and delivery

2. **AccessRegistry**: Used for controlling access to bridge operations
   - Determines which accounts can perform bridging operations directly, without the need for authorization from the issuer


### Setup Adapter Contracts

1. Install dependencies in the smart contract project folder, `lz-oapp`

   ```
   yarn install
   ```

2. Configure environment
   - Create a `local.env` file based on `.env.example`
     - Only fill in private key or mnemonic, if you want to deploy and configure the Adapters 
       using an external key (not recommended for production)
     - Fill in the Fireblocks API key and private key path to use the Fireblocks API to sign transactions (recommended for production)
   - Set RPC URLs for the networks you want to use

3. Update token addresses in hardhat.config.ts
   - The `oftAdapter.tokenAddress` property in each network configuration should point to your WUSD token contract
     on that network. This will ensure the correct deployment of the Adapter contracts.

## Deployment

### WUSDAdapter Deployment

1. Deploy adapters using LayerZero tooling

   ```
   npx hardhat lz:deploy --network sepolia
   ```

   This will deploy the WusdOFTAdapter contract on the specified network. Repeat for each network you want to bridge between.

2. Wire adapters across networks

   ```
   npx hardhat lz:wire --network sepolia
   ```
   
   This configures the adapters to talk to each other across chains. The `--network` parameter is required to ensure the correct Fireblocks provider is loaded.

### Contract Verification

Verify your contracts on block explorers:

```
npx hardhat verify --network sepolia DEPLOYED_CONTRACT_ADDRESS
```

## Role Setup

After deployment, set up the required roles:

1. Grant the `AUTHORIZER_ROLE` to accounts that can authorize token transfers
   ```typescript
   await wusdOftAdapter.grantRole(await wusdOftAdapter.AUTHORIZER_ROLE(), authorizerAddress)
   ```

2. Grant the `MINTER_ROLE` and `BURNER_ROLE` on the ERC20F tokens to the adapter
   ```typescript
   await token.grantRole(await token.MINTER_ROLE(), adapterAddress)
   await token.grantRole(await token.BURNER_ROLE(), adapterAddress)
   ```

## User Workflow

1. **Grant Approval**: User approves the adapter to spend their tokens
   ```typescript
   await token.approve(adapterAddress, amountToSend)
   ```

2. **Get Authorization**: An account with AUTHORIZER_ROLE signs a message authorizing the transfer

3. **Initiate Bridging**: User calls `sendWithAuthorization` with the signed authorization to bridge tokens
   ```typescript
   await adapter.sendWithAuthorization(
     authorization,
     v, r, s,
     messagingFee,
     refundAddress,
     { value: messagingFee.nativeFee }
   )
   ```

4. **View Transaction**: Monitor the transaction on LayerZero Scan

## Sample dApp

A sample Next.js application is provided to demonstrate integration with the bridging solution.

### Setup Sample dApp

1. Navigate to the sample-dapp directory
   ```
   cd sample-dapp
   ```

2. Install dependencies
   ```
   yarn install
   ```

3. Update the configuration
   - Update token addresses in `src/app/config/tokens.ts`
   - Verify OmniPoint configuration in `src/app/config/omniPointMap.ts`

4. Start the development server
   ```
   yarn dev
   ```

## Configuration Files

### hardhat.config.ts
Contains network configurations and token addresses for deployment.

```typescript
'holesky-testnet': {
  eid: EndpointId.HOLESKY_V2_TESTNET,
  url: process.env.RPC_URL_HOLESKY || 'https://ethereum-holesky-rpc.publicnode.com',
  accounts,
  oftAdapter: {
    tokenAddress: '0xDdCb87d9CAdB7a030f35cD890Be49F7554473638',
  },
},
'sepolia-testnet': {
  eid: EndpointId.SEPOLIA_V2_TESTNET,
  url: process.env.RPC_URL_SEPOLIA || 'https://eth-sepolia.public.blastapi.io',
  accounts,
  oftAdapter: {
    tokenAddress: '0xaF16E77FbF7Ca7649387124E7d4061c7e95206A1',
  },
},
```

### testnet.layerzero.config.ts
Defines the OmniGraph for connecting contracts across chains.

```typescript
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
```

## Project Structure

```
wspn-bridging/
├── contracts/                # Smart contract code
│   └── WusdOFTAdapter.sol    # Main adapter contract
├── scripts/                  # Deployment and management scripts
├── test/                     # Test files
│   └── hardhat/              # Hardhat-specific tests
├── sample-dapp/              # Next.js demo application
│   └── src/app/config/       # Configuration files
├── config/                   # Project configuration
└── hardhat.config.ts         # Hardhat configuration
```

## Technical Details

The WusdOFTAdapter implements the following key features:

1. **Token Bridging**: Burn tokens on source chain and mint on destination chain
2. **Authorization**: Requires signed approval from an authorized account
3. **Embargo Mechanism**: Safety feature for handling failed token deliveries
4. **Role-Based Access Control**: Different roles for different operations

## Troubleshooting

### Common Issues

1. **LayerZero Endpoint Connection**
   - Ensure the correct endpoint ID is configured for each chain
   - Verify that the contracts are properly wired using `lz:wire`

2. **Authorization Errors**
   - Check if the authorizer has the AUTHORIZER_ROLE
   - Verify that the signature parameters (v, r, s) are correctly calculated

3. **Token Allowance**
   - Ensure users have approved enough tokens before bridging
   - Check if the adapter has MINTER_ROLE and BURNER_ROLE on the token

4. **Embargo Situations**
   - If tokens are in embargo, they can be released using `releaseEmbargo` or `recoverEmbargo`


## Additional Resources

- [LayerZero Documentation](https://layerzero.gitbook.io/docs/)
- [OFT Standard](https://layerzero.gitbook.io/docs/evm-guides/layerzero-omnichain-contracts/oft-overview)
- [Fireblocks Documentation](https://developers.fireblocks.com/)
