import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract, ContractFactory } from 'ethers'
import hre, { deployments, ethers } from 'hardhat'

import { Options } from '@layerzerolabs/lz-v2-utilities'
import { _TypedDataEncoder } from 'ethers/lib/utils'
import {
    deployERC20FImplementation,
    deployERC20FProxy,
    ERC20F_ABI,
} from './external-deployments/deploy-upgradeable-erc20f'
import { WusdOFTAdapter, WusdOFTAdapter__factory, AccessRegistryMock, IERC20F } from '../../typechain-types'
import { SendParamStruct, IWusdOFTAdapter } from '../../typechain-types/contracts/WusdOFTAdapter'

// NOTE: Raising the concern of the mock LZEndpoint being significantly different from the real LZEndpoint.
//       This was noticed when listing the steps required to wire the OFTAdapter to the endpoint and peers.
//       The real EndpointV2 does not support the setDestLzEndpoint function.
// NOTE: The Mock Endpoint being used here is from @layerzerolabs/test-devtools-evm-hardhat.
//       However, the Mock Endpoint from @layerzerolabs/test-devtools-evm-foundry is way more similar
//       to the real EndpointV2.
// NOTE: Sources:
//       [EndpointV2](https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/protocol/contracts/EndpointV2.sol)
//       [Hardhat EndpointV2Mock](https://github.com/LayerZero-Labs/devtools/blob/main/packages/test-devtools-evm-hardhat/contracts/mocks/EndpointV2Mock.sol)
//       [Foundry EndpointV2Mock](https://github.com/LayerZero-Labs/devtools/blob/main/packages/test-devtools-evm-foundry/contracts/mocks/EndpointV2Mock.sol)

/**
 * This test will not run on a public testnet. This is because it uses a mock LZEndpoint
 * from @layerzerolabs/test-devtools-evm-hardhat.
 *
 * However, this test leverages on such library to test full integration with ERC20F (upgradeable)
 * and WusdOFTAdapter.
 */
describe('WusdOFTAdapter Integration Test', function () {
    // Constant representing a mock Endpoint ID for testing purposes
    const eidA = 1
    const eidB = 2
    // Declaration of variables to be used in the test suite
    let WusdOFTAdapter: ContractFactory
    let EndpointV2Mock: ContractFactory
    let AccessRegistryMock: ContractFactory
    let deployer: SignerWithAddress
    let superAdminTokenA: SignerWithAddress
    let superAdminTokenB: SignerWithAddress
    let endpointOwner: SignerWithAddress
    let defaultAdminAdapterA: SignerWithAddress
    let defaultAdminAdapterB: SignerWithAddress
    let contractAdminAdapterA: SignerWithAddress
    let contractAdminAdapterB: SignerWithAddress
    let tokenHolder: SignerWithAddress
    let bridgeOperatorA: SignerWithAddress
    let tokenA: IERC20F
    let tokenB: IERC20F
    let wusdOftAdapterA: WusdOFTAdapter
    let wusdOftAdapterB: WusdOFTAdapter
    let mockEndpointV2A: Contract
    let mockEndpointV2B: Contract
    let accessRegistryA: AccessRegistryMock
    const initialBalance = ethers.BigNumber.from(1000)

    // Before hook for setup that runs once before all tests in the block
    // Only performs deployment stage - no configurations, which is left to the tests
    beforeEach(async function () {
        // Fetching the first signers (in order) from Hardhat's local Ethereum network
        const signers = await ethers.getSigners()
        ;[
            deployer,
            superAdminTokenA,
            superAdminTokenB,
            endpointOwner,
            defaultAdminAdapterA,
            defaultAdminAdapterB,
            contractAdminAdapterA,
            contractAdminAdapterB,
            tokenHolder,
            bridgeOperatorA,
        ] = signers

        // Deploy two ERC20F instances
        const implAddress = await deployERC20FImplementation(deployer)
        const erc20fA = await deployERC20FProxy(
            deployer,
            implAddress,
            'WUSD A',
            'WUSD',
            superAdminTokenA.address,
            superAdminTokenA.address,
            superAdminTokenA.address
        )
        const erc20fB = await deployERC20FProxy(
            deployer,
            implAddress,
            'WUSD B',
            'WUSD',
            superAdminTokenB.address,
            superAdminTokenB.address,
            superAdminTokenB.address
        )
        // Get AccessRegistryMock contract factory
        const AccessRegistryMockArtifact = await deployments.getArtifact('AccessRegistryMock')
        AccessRegistryMock = new ContractFactory(
            AccessRegistryMockArtifact.abi,
            AccessRegistryMockArtifact.bytecode,
            deployer
        )

        // Deploy AccessRegistryMock
        accessRegistryA = (await AccessRegistryMock.deploy()) as AccessRegistryMock
        await accessRegistryA.deployed()

        // Contract factory for our tested contract
        WusdOFTAdapter = (await ethers.getContractFactory('WusdOFTAdapter')) as WusdOFTAdapter__factory

        // The EndpointV2Mock contract comes from @layerzerolabs/test-devtools-evm-hardhat package
        // and its artifacts are connected as external artifacts to this project
        //
        // Unfortunately, hardhat itself does not yet provide a way of connecting external artifacts,
        // so we rely on hardhat-deploy to create a ContractFactory for EndpointV2Mock
        //
        // See https://github.com/NomicFoundation/hardhat/issues/1040
        const EndpointV2MockArtifact = await deployments.getArtifact('EndpointV2Mock')
        EndpointV2Mock = new ContractFactory(EndpointV2MockArtifact.abi, EndpointV2MockArtifact.bytecode, endpointOwner)
        // Deploying a mock LZEndpoint with the given Endpoint ID
        mockEndpointV2A = await EndpointV2Mock.deploy(eidA)
        mockEndpointV2B = await EndpointV2Mock.deploy(eidB)
        // Deploying two instances of WusdOFTAdapter contract with different identifiers
        wusdOftAdapterA = (await WusdOFTAdapter.deploy(
            erc20fA.address,
            mockEndpointV2A.address,
            defaultAdminAdapterA.address,
            contractAdminAdapterA.address
        )) as WusdOFTAdapter
        wusdOftAdapterB = (await WusdOFTAdapter.deploy(
            erc20fB.address,
            mockEndpointV2B.address,
            defaultAdminAdapterB.address,
            contractAdminAdapterB.address
        )) as WusdOFTAdapter
        tokenA = new ethers.Contract(erc20fA.address, ERC20F_ABI, deployer) as IERC20F
        tokenB = new ethers.Contract(erc20fB.address, ERC20F_ABI, deployer) as IERC20F
        wusdOftAdapterA = await wusdOftAdapterA.deployed()
        wusdOftAdapterB = await wusdOftAdapterB.deployed()
    })

    // beforeEach hook for setup that runs before each test in the block
    beforeEach(async function () {
        // // Setting each MyOFT instance as a peer of the other in the mock LZEndpoint
        // await myOFTAdapter.connect(superAdminTokenA).setPeer(eidB, ethers.utils.zeroPad(myOFTB.address, 32))
        // await myOFTB.connect(superAdminTokenB).setPeer(eidA, ethers.utils.zeroPad(myOFTAdapter.address, 32))
    })

    it(`1. Sets the destination endpoints (Hardhat EndpointV2Mock only)
        2. Sets the AccessRegistry mock to WusdAdapter A
        3. Adds bridgeOperatorA to the AccessRegistry allowlist
        4. Wires the Adapters to each other
        5. Grants Minter and Burner roles on the Tokens to the Adapters
        6. Establishes a sender allowlist for the WusdAdapter on chain A
        7. Mints tokens to the tokenHolder
        8. Sends a token from A address to B address via OFTAdapter/OFT
        `, async function () {
        // Setting destination endpoints in the LZEndpoint mock for each Adapter instance (Hardhat EndpointV2Mock only)
        await mockEndpointV2A.setDestLzEndpoint(wusdOftAdapterB.address, mockEndpointV2B.address)
        await mockEndpointV2B.setDestLzEndpoint(wusdOftAdapterA.address, mockEndpointV2A.address)

        // Set access registry on WusdAdapter A
        await wusdOftAdapterA
            .connect(defaultAdminAdapterA)
            .grantRole(await wusdOftAdapterA.CONTRACT_ADMIN_ROLE(), defaultAdminAdapterA.address)
        await wusdOftAdapterA.connect(defaultAdminAdapterA).accessRegistryUpdate(accessRegistryA.address)

        // Add bridgeOperatorA to the access registry allowlist
        await accessRegistryA.setAccess(bridgeOperatorA.address, true)

        // Grant Minter and Burner roles on the Tokens to the Adapters
        await tokenA.connect(superAdminTokenA).grantRole(await tokenA.MINTER_ROLE(), wusdOftAdapterA.address)
        await tokenA.connect(superAdminTokenA).grantRole(await tokenA.BURNER_ROLE(), wusdOftAdapterA.address)
        await tokenB.connect(superAdminTokenB).grantRole(await tokenB.MINTER_ROLE(), wusdOftAdapterB.address)
        await tokenB.connect(superAdminTokenB).grantRole(await tokenB.BURNER_ROLE(), wusdOftAdapterB.address)

        // Wire the Adapters to each other, by setting each Adapter instance as a peer of the other in the LZEndpoint,
        // using superAdmin (who has CONTRACT_ADMIN_ROLE)
        await wusdOftAdapterA
            .connect(contractAdminAdapterA)
            .setPeer(eidB, ethers.utils.zeroPad(wusdOftAdapterB.address, 32))
        await wusdOftAdapterB
            .connect(contractAdminAdapterB)
            .setPeer(eidA, ethers.utils.zeroPad(wusdOftAdapterA.address, 32))

        // Mint tokens to the tokenHolder
        const decimals = await tokenA.decimals()
        const tokenAmountA = initialBalance.mul(ethers.BigNumber.from(10).pow(decimals))
        await tokenA.connect(superAdminTokenA).mint(tokenHolder.address, tokenAmountA)

        // Verify initial setup
        expect(await wusdOftAdapterA.accessRegistry()).to.equal(accessRegistryA.address)
        expect(await tokenA.hasRole(await tokenA.MINTER_ROLE(), wusdOftAdapterA.address)).to.be.true
        expect(await tokenA.hasRole(await tokenA.BURNER_ROLE(), wusdOftAdapterA.address)).to.be.true
        expect(await tokenB.hasRole(await tokenB.MINTER_ROLE(), wusdOftAdapterB.address)).to.be.true
        expect(await tokenB.hasRole(await tokenB.BURNER_ROLE(), wusdOftAdapterB.address)).to.be.true
        expect(await accessRegistryA.hasAccess(bridgeOperatorA.address, ethers.constants.AddressZero, '0x')).to.be.true
        expect(await accessRegistryA.hasAccess(tokenHolder.address, ethers.constants.AddressZero, '0x')).to.be.false
        expect(await tokenA.balanceOf(tokenHolder.address)).to.equal(tokenAmountA)
        expect(await tokenB.balanceOf(tokenHolder.address)).to.equal(ethers.BigNumber.from(0))
        expect(await tokenA.balanceOf(bridgeOperatorA.address)).to.equal(ethers.BigNumber.from(0))
        expect(await tokenB.balanceOf(bridgeOperatorA.address)).to.equal(ethers.BigNumber.from(0))
        expect(await tokenA.balanceOf(wusdOftAdapterA.address)).to.equal(ethers.BigNumber.from(0))
        expect(await tokenB.balanceOf(wusdOftAdapterB.address)).to.equal(ethers.BigNumber.from(0))

        // Bridging actions
        const tokensToSend = tokenAmountA
        const deadline = Math.floor(Date.now() / 1000) + 60 * 5 // 5 minutes from now

        // 1st element: Gas limit for the executor,
        // 2nd element: msg.value for the lzReceive() function on destination in wei
        const options = Options.newOptions().addExecutorLzReceiveOption(300000, 0).toHex().toString()
        // Create SendParam
        const sendParam: SendParamStruct = {
            dstEid: eidB,
            to: ethers.utils.zeroPad(tokenHolder.address, 32),
            amountLD: tokensToSend,
            minAmountLD: tokensToSend,
            extraOptions: options,
            composeMsg: '0x',
            oftCmd: '0x',
        }

        // Generate permit signature
        const permitDomain = {
            name: await tokenA.name(),
            version: '1',
            chainId: (await ethers.provider.getNetwork()).chainId,
            verifyingContract: tokenA.address,
        }

        const permitTypes = {
            Permit: [
                { name: 'owner', type: 'address' },
                { name: 'spender', type: 'address' },
                { name: 'value', type: 'uint256' },
                { name: 'nonce', type: 'uint256' },
                { name: 'deadline', type: 'uint256' },
            ],
        }

        const permitValues = {
            owner: tokenHolder.address,
            spender: wusdOftAdapterA.address,
            value: tokensToSend,
            nonce: await tokenA.nonces(tokenHolder.address),
            deadline: deadline,
        }

        const permitSignature = await tokenHolder._signTypedData(permitDomain, permitTypes, permitValues)
        const permitSplit = ethers.utils.splitSignature(permitSignature)

        // Create Authorization
        const authorization: IWusdOFTAdapter.OFTSendAuthorizationStruct = {
            owner: permitValues.owner,
            value: permitValues.value,
            permitNonce: permitValues.nonce,
            deadline: deadline,
            sendParams: sendParam,
            nonce: await wusdOftAdapterA.nonces(tokenHolder.address),
        }

        // Generate send authorization signature using ethers
        const authDomain = {
            name: 'WusdOFTAdapter',
            version: '1',
            chainId: (await ethers.provider.getNetwork()).chainId,
            verifyingContract: wusdOftAdapterA.address,
        }

        const authTypes = {
            OFTSendAuthorization: [
                { name: 'owner', type: 'address' },
                { name: 'value', type: 'uint256' },
                { name: 'permitNonce', type: 'uint256' },
                { name: 'deadline', type: 'uint256' },
                { name: 'sendParams', type: 'SendParam' },
                { name: 'nonce', type: 'uint256' },
            ],
            SendParam: [
                { name: 'dstEid', type: 'uint32' },
                { name: 'to', type: 'bytes32' },
                { name: 'amountLD', type: 'uint256' },
                { name: 'minAmountLD', type: 'uint256' },
                { name: 'extraOptions', type: 'bytes' },
                { name: 'composeMsg', type: 'bytes' },
                { name: 'oftCmd', type: 'bytes' },
            ],
        }

        // Get the ethers-generated hash. Uncomment if needed for debugging
        // const ethersPayload = _TypedDataEncoder.getPayload(authDomain, authTypes, authorization)
        // console.log('Ethers payload:', JSON.stringify(ethersPayload, null, 2))
        // const ethersHash = _TypedDataEncoder.hash(authDomain, authTypes, authorization)
        // console.log('Ethers hash:', ethersHash)

        // Use the modified values for signing
        const authSignature = await tokenHolder._signTypedData(authDomain, authTypes, authorization)
        const authSplit = ethers.utils.splitSignature(authSignature)

        // Get messaging fee
        const messagingFee = await wusdOftAdapterA.quoteSend(sendParam, false)

        // Execute sendWithAuthorization from bridgeOperatorA
        await wusdOftAdapterA
            .connect(bridgeOperatorA)
            .sendWithAuthorization(
                authorization,
                permitSplit.v,
                permitSplit.r,
                permitSplit.s,
                authSplit.v,
                authSplit.r,
                authSplit.s,
                messagingFee,
                bridgeOperatorA.address,
                { value: messagingFee.nativeFee }
            )

        // Verify the transfer was successful
        const decimalConversionRate = ethers.BigNumber.from(10).pow(
            (await tokenA.decimals()) - (await tokenB.decimals())
        )
        const expectedTokensOnB = tokensToSend.div(decimalConversionRate)

        // Verify token balances
        expect(await tokenA.balanceOf(tokenHolder.address)).to.equal(tokenAmountA.sub(tokensToSend))
        expect(await tokenB.balanceOf(tokenHolder.address)).to.equal(expectedTokensOnB)
        expect(await tokenA.balanceOf(wusdOftAdapterA.address)).to.equal(0) // Tokens are burned
        expect(await tokenB.balanceOf(wusdOftAdapterB.address)).to.equal(0) // Tokens are minted and sent to recipient
        expect(await tokenA.balanceOf(bridgeOperatorA.address)).to.equal(0)
        expect(await tokenB.balanceOf(bridgeOperatorA.address)).to.equal(0)
        // Verify nonces were incremented
        expect(await wusdOftAdapterA.nonces(tokenHolder.address)).to.equal(1)
        expect(await wusdOftAdapterA.nonces(bridgeOperatorA.address)).to.equal(0)
    })
})
