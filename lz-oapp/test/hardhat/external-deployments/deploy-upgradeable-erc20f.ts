import hre, { ethers } from 'hardhat'
import { writeFileSync } from 'fs'
import { join } from 'path'
import ERC20F from '../../external-artifacts/ERC20F.json'
import ERC1967Proxy from '../../external-artifacts/ERC1967Proxy.json'
import { Contract, Signer } from 'ethers'
import { IERC20F } from '../../../typechain-types'

export const deployERC20FImplementation = async (signer: Signer): Promise<string> => {
    const ERC20FFactory = await hre.ethers.getContractFactory(ERC20F.abi, ERC20F.bytecode.object)
    console.log(`Sending transaction to deploy ERC20F implementation`)
    const erc20fImpl = await ERC20FFactory.connect(signer).deploy()
    await erc20fImpl.deployed()
    console.log(`ERC20F implementation deployed at ${erc20fImpl.address}`)
    return erc20fImpl.address
}

export const deployERC20FProxy = async (
    signer: Signer,
    erc20fImplAddress: string,
    name: string,
    symbol: string,
    defaultAdmin: string,
    minter: string,
    pauser: string
): Promise<IERC20F> => {
    const ERC20FFactory = await hre.ethers.getContractFactory(ERC20F.abi, ERC20F.bytecode.object)
    const initData = ERC20FFactory.interface.encodeFunctionData('initialize', [
        name,
        symbol,
        defaultAdmin,
        minter,
        pauser,
    ])
    const ProxyFactory = new ethers.ContractFactory(ERC1967Proxy.abi, ERC1967Proxy.bytecode.object, signer)
    console.log(`Sending transaction to deploy ERC20F (${name}, ${symbol}) entrypoint`)
    let proxy = (await ProxyFactory.deploy(erc20fImplAddress, initData)) as IERC20F
    await proxy.deployed()
    console.log(`ERC20F proxy deployed at ${proxy.address}`)
    return proxy
}

export const ERC20F_ABI = ERC20F.abi
