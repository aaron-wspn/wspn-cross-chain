import assert from 'assert'
import dotenv from 'dotenv'

import { type DeployFunction } from 'hardhat-deploy/types'
import { IERC20F } from '../typechain-types'

// Load environment variables
dotenv.config({ path: './local.env' })

const contractName = 'WusdOFTAdapter'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { deploy } = deployments
    // const { deployer } = await getNamedAccounts()
    const accounts = await getNamedAccounts()
    const { deployer } = accounts
    const signers = await hre.ethers.getSigners()

    assert(deployer, 'Missing named deployer account')
    console.log(`Deploying ${contractName}...`)
    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)

    // This is an external deployment pulled in from @layerzerolabs/lz-evm-sdk-v2
    //
    // @layerzerolabs/toolbox-hardhat takes care of plugging in the external deployments
    // from @layerzerolabs packages based on the configuration in your hardhat config
    //
    // For this to work correctly, your network config must define an eid property
    // set to `EndpointId` as defined in @layerzerolabs/lz-definitions
    //
    // For example:
    //
    // networks: {
    //   fuji: {
    //     ...
    //     eid: EndpointId.AVALANCHE_V2_TESTNET
    //   }
    // }
    const endpointV2Deployment = await hre.deployments.get('EndpointV2')

    // The token address must be defined in hardhat.config.ts
    // If the token address is not defined, the deployment will log a warning and skip the deployment
    if (hre.network.config.oftAdapter == null) {
        console.warn(`oftAdapter not configured on network config, skipping OFTWrapper deployment`)

        return
    }

    if (!process.env.ADAPTER_DEFAULT_ADMIN_ADDRESS || !process.env.ADAPTER_DELEGATE_ADDRESS) {
        throw new Error(
            'ADAPTER_DEFAULT_ADMIN_ADDRESS and ADAPTER_DELEGATE_ADDRESS must be set in environment variables'
        )
    }

    const { address } = await deploy(contractName, {
        from: deployer,
        args: [
            hre.network.config.oftAdapter.tokenAddress, // token address
            endpointV2Deployment.address, // LayerZero's EndpointV2 address
            process.env.ADAPTER_DEFAULT_ADMIN_ADDRESS, // defaultAdmin
            process.env.ADAPTER_DELEGATE_ADDRESS, // delegate / OApp Admin
        ],
        log: true,
        skipIfAlreadyDeployed: false,
    })

    let tokenContract = (await hre.ethers.getContractAt(
        'IERC20F',
        hre.network.config.oftAdapter.tokenAddress
    )) as IERC20F
    const name = await tokenContract.name()
    const decimals = await tokenContract.decimals()
    console.log(`Token Name: ${name}`)
    console.log(`Decimals: ${decimals}`)
    tokenContract = tokenContract.connect(hre.ethers.provider.getSigner(deployer))

    console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${address}`)
    console.log(`Granting required roles (Minter, Burner) on ${name} to Adapter...`)
    // Grant Minter and Burner roles to the OFT Adapter
    const mrtx = await tokenContract.grantRole(await tokenContract.MINTER_ROLE(), address)
    await mrtx.wait()
    const grtx = await tokenContract.grantRole(await tokenContract.BURNER_ROLE(), address)
    await grtx.wait()
    console.log(`Granted required roles (Minter, Burner) on ${name} to Adapter...`)
    return
}

deploy.tags = [contractName]

export default deploy
