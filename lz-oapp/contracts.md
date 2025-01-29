
## OApp, OFT and Adapter core docs

Methods in use behind `onlyOwner` modifier:

- [OAppCore](https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/oapp/contracts/oapp/OAppCore.sol)
  - `setPeer(uint32 _eid, bytes32 _peer)`
  - `setDelegate(address _delegate)`
- [OAppRead](https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/oapp/contracts/oapp/OAppRead.sol)
  - `setReadChannel(uint32 _channelId, bool _active)`
- [OAppOptionsType3](https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/oapp/contracts/oapp/libs/OAppOptionsType3.sol)
  - `setEnforcedOptions(EnforcedOptionParam[] calldata _enforcedOptions)`
- [OAppPreCrimeSimulator](https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/oapp/contracts/precrime/OAppPreCrimeSimulator.sol)
  - `setPreCrime(address _preCrime)`
- [OFTCore](https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/oapp/contracts/oft/OFTCore.sol)
  - `setMsgInspector(address _msgInspector)`
