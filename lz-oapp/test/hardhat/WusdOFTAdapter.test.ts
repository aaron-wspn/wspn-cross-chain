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
    let authorizer: SignerWithAddress
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
            authorizer,
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
        // Deploying mock LZEndpoints
        mockEndpointV2A = await EndpointV2Mock.deploy(eidA)
        mockEndpointV2B = await EndpointV2Mock.deploy(eidB)
        // Deploying WusdOFTAdapter instances
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
        3. Grants AUTHORIZER_ROLE to authorizer
        4. Wires the Adapters to each other
        5. Grants Minter and Burner roles on the Tokens to the Adapters
        6. Mints tokens to the tokenHolder
        7. Approves (TokenHolder) tokens for the OFTAdapter
        8. Signs (Authorizer) an authorization to send tokens
        9. Gets the messaging fee
        10. Sends (TokenHolder) tokens B address via OFTAdapter, bound to the authorization received
        `, async function () {
        // 1. Setting destination endpoints in the LZEndpoint mock for each Adapter instance (Hardhat EndpointV2Mock only)
        await mockEndpointV2A.setDestLzEndpoint(wusdOftAdapterB.address, mockEndpointV2B.address)
        await mockEndpointV2B.setDestLzEndpoint(wusdOftAdapterA.address, mockEndpointV2A.address)

        // 2. Set access registry on WusdAdapter A
        await wusdOftAdapterA.connect(contractAdminAdapterA).accessRegistryUpdate(accessRegistryA.address)

        // 3. Grant AUTHORIZER_ROLE to authorizer on both Adapters
        await wusdOftAdapterA
            .connect(defaultAdminAdapterA)
            .grantRole(await wusdOftAdapterA.AUTHORIZER_ROLE(), authorizer.address)
        await wusdOftAdapterB
            .connect(defaultAdminAdapterB)
            .grantRole(await wusdOftAdapterB.AUTHORIZER_ROLE(), authorizer.address)

        // 4. Wire the Adapters to each other, by setting each Adapter instance as a peer of the other in the LZEndpoint,
        // using superAdmin (who has CONTRACT_ADMIN_ROLE)
        await wusdOftAdapterA
            .connect(contractAdminAdapterA)
            .setPeer(eidB, ethers.utils.zeroPad(wusdOftAdapterB.address, 32))
        await wusdOftAdapterB
            .connect(contractAdminAdapterB)
            .setPeer(eidA, ethers.utils.zeroPad(wusdOftAdapterA.address, 32))

        // 5. Grant Minter and Burner roles on the Tokens to the Adapters
        await tokenA.connect(superAdminTokenA).grantRole(await tokenA.MINTER_ROLE(), wusdOftAdapterA.address)
        await tokenA.connect(superAdminTokenA).grantRole(await tokenA.BURNER_ROLE(), wusdOftAdapterA.address)
        await tokenB.connect(superAdminTokenB).grantRole(await tokenB.MINTER_ROLE(), wusdOftAdapterB.address)
        await tokenB.connect(superAdminTokenB).grantRole(await tokenB.BURNER_ROLE(), wusdOftAdapterB.address)

        // 6. Mint tokens to tokenHolder
        const decimals = await tokenA.decimals()
        const tokenAmountA = initialBalance.mul(ethers.BigNumber.from(10).pow(decimals))
        await tokenA.connect(superAdminTokenA).mint(tokenHolder.address, tokenAmountA)

        // Verify initial setup
        expect(await wusdOftAdapterA.accessRegistry()).to.equal(accessRegistryA.address)
        expect(await tokenA.hasRole(await tokenA.MINTER_ROLE(), wusdOftAdapterA.address)).to.be.true
        expect(await tokenA.hasRole(await tokenA.BURNER_ROLE(), wusdOftAdapterA.address)).to.be.true
        expect(await tokenB.hasRole(await tokenB.MINTER_ROLE(), wusdOftAdapterB.address)).to.be.true
        expect(await tokenB.hasRole(await tokenB.BURNER_ROLE(), wusdOftAdapterB.address)).to.be.true
        // authorizer does not need to be in the allowlist
        expect(await accessRegistryA.hasAccess(authorizer.address, ethers.constants.AddressZero, '0x')).to.be.false
        expect(await accessRegistryA.hasAccess(tokenHolder.address, ethers.constants.AddressZero, '0x')).to.be.false
        // authorizer does need to have the AUTHORIZER_ROLE
        expect(await wusdOftAdapterA.hasRole(await wusdOftAdapterA.AUTHORIZER_ROLE(), authorizer.address)).to.be.true
        expect(await tokenA.balanceOf(tokenHolder.address)).to.equal(tokenAmountA)
        expect(await tokenB.balanceOf(tokenHolder.address)).to.equal(0)
        expect(await tokenA.balanceOf(authorizer.address)).to.equal(0)
        expect(await tokenB.balanceOf(authorizer.address)).to.equal(0)
        expect(await tokenA.balanceOf(wusdOftAdapterA.address)).to.equal(0)
        expect(await tokenB.balanceOf(wusdOftAdapterB.address)).to.equal(0)

        // Bridging variables
        const tokensToSend = tokenAmountA
        // 7. Approve tokens
        await tokenA.connect(tokenHolder).approve(wusdOftAdapterA.address, tokensToSend)

        // Constructing the SendParam
        const deadline = Math.floor(Date.now() / 1000) + 60 * 15 // 15 minutes from now
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
        // Create Authorization
        const nonceKey = await wusdOftAdapterA.addressToNonceKey(tokenHolder.address)
        const authorization: IWusdOFTAdapter.OFTSendAuthorizationStruct = {
            authorizer: authorizer.address,
            sender: tokenHolder.address,
            sendParams: sendParam,
            deadline: deadline,
            nonce: await wusdOftAdapterA['nonces(address,uint192)'](authorizer.address, nonceKey),
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
                { name: 'authorizer', type: 'address' },
                { name: 'sender', type: 'address' },
                { name: 'sendParams', type: 'SendParam' },
                { name: 'deadline', type: 'uint256' },
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

        // 8. Use the types and values for signing the authorization
        const authSignature = await authorizer._signTypedData(authDomain, authTypes, authorization)
        const authSplit = ethers.utils.splitSignature(authSignature)

        // 9. Get messaging fee
        const messagingFee = await wusdOftAdapterA.quoteSend(sendParam, false)

        // Initial balance checks
        expect(await tokenA.balanceOf(tokenHolder.address)).to.equal(tokensToSend)
        expect(await tokenB.balanceOf(tokenHolder.address)).to.equal(0)

        // 10. Execute sendWithAuthorization
        await wusdOftAdapterA
            .connect(tokenHolder)
            .sendWithAuthorization(
                authorization,
                authSplit.v,
                authSplit.r,
                authSplit.s,
                messagingFee,
                tokenHolder.address,
                {
                    value: messagingFee.nativeFee,
                }
            )

        // Calculate expected tokens on chain B (considering decimal conversion)
        const decimalConversionRate = ethers.BigNumber.from(10).pow(
            (await tokenA.decimals()) - (await tokenB.decimals())
        )
        const expectedTokensOnB = tokensToSend.div(decimalConversionRate)

        // Verify token balances
        expect(await tokenA.balanceOf(tokenHolder.address)).to.equal(tokenAmountA.sub(tokensToSend))
        expect(await tokenB.balanceOf(tokenHolder.address)).to.equal(expectedTokensOnB)
        expect(await tokenA.balanceOf(wusdOftAdapterA.address)).to.equal(0) // Tokens are burned
        expect(await tokenB.balanceOf(wusdOftAdapterB.address)).to.equal(0) // Tokens are minted and sent to recipient
        expect(await tokenA.balanceOf(authorizer.address)).to.equal(0)
        expect(await tokenB.balanceOf(authorizer.address)).to.equal(0)
        // Verify correct nonces were incremented
        expect(await wusdOftAdapterA['nonces(address,uint192)'](tokenHolder.address, nonceKey)).to.equal(0)
        expect(await wusdOftAdapterA['nonces(address,uint192)'](authorizer.address, nonceKey)).to.equal(1)
    })
})
