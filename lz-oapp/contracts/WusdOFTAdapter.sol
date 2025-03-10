// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2024 Fireblocks <support@fireblocks.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EnumerableMap } from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { NoncesKeyed } from "@openzeppelin/contracts/utils/NoncesKeyed.sol";
import { OFTCore } from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import { IOFT, SendParam, OFTReceipt, MessagingReceipt, MessagingFee } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { IERC20F } from "./interfaces/IERC20F.sol";
import { IWusdOFTAdapter } from "./interfaces/IWusdOFTAdapter.sol";
import { AccessRegistrySubscriptionCapable } from "./modules/AccessRegistrySubscriptionCapable.sol";
import { RoleBasedOwnable } from "./modules/RoleBasedOwnable.sol";
import { PauseCapable } from "./modules/PauseCapable.sol";
import { SalvageCapable } from "./modules/SalvageCapable.sol";
import { LibErrors } from "./library/LibErrors.sol";
import { LibRoles } from "./library/LibRoles.sol";

// import "forge-std/console.sol";
// import { console } from "hardhat/console.sol";

/**
 * @title OFTAdapter Contract
 * @dev OFTAdapter is a contract that adapts an ERC-20 token to the OFT functionality.
 *
 * @dev For existing ERC20F tokens, this utility contract adds crosschain compatibility.
 * @dev WARNING: The default OFTAdapter implementation assumes LOSSLESS transfers, ie. 1 token in, 1 token out.
 * IF the 'innerToken' applies something like a transfer fee, the default will NOT work...
 * a pre/post balance check will need to be done to calculate the amountSentLD/amountReceivedLD.
 */
contract WusdOFTAdapter is
    IWusdOFTAdapter,
    OFTCore,
    EIP712,
    NoncesKeyed,
    AccessRegistrySubscriptionCapable,
    RoleBasedOwnable,
    PauseCapable,
    SalvageCapable
{
    // Extension methods via Libraries
    using SafeERC20 for IERC20;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    // Constants
    /**
     * @notice The typehash for the OFTSendAuthorization struct.
     */
    bytes32 public constant SEND_AUTHORIZATION_TYPEHASH =
        keccak256(
            "OFTSendAuthorization(address authorizer,address sender,SendParam sendParams,uint256 deadline,uint256 nonce)SendParam(uint32 dstEid,bytes32 to,uint256 amountLD,uint256 minAmountLD,bytes extraOptions,bytes composeMsg,bytes oftCmd)"
        );

    /**
     * @notice The typehash for the SendParam struct.
     */
    bytes32 public constant SEND_PARAM_TYPEHASH =
        keccak256(
            "SendParam(uint32 dstEid,bytes32 to,uint256 amountLD,uint256 minAmountLD,bytes extraOptions,bytes composeMsg,bytes oftCmd)"
        );

    // Roles
    /**
     * @notice The Access Control identifier for the Contract Admin Role. These role overarches two purposes:
     *
     * 1. Update the Access Registry.
     * 2. Update the OApp configurations, i.e. those inherited from OApp that are restricted to `onlyOwner`.
     *
     * @dev This constant holds the hash of the string "CONTRACT_ADMIN_ROLE".
     */
    bytes32 public constant CONTRACT_ADMIN_ROLE = LibRoles.CONTRACT_ADMIN_ROLE;

    /**
     * @notice The Access Control identifier for the Pauser Role.
     * An account with "PAUSER_ROLE" can pause the contract.
     *
     * @dev This constant holds the hash of the string "PAUSER_ROLE".
     */
    bytes32 public constant PAUSER_ROLE = LibRoles.PAUSER_ROLE;

    /**
     * @notice The Access Control identifier for the Authorizer Role.
     * An account with "AUTHORIZER_ROLE" can authorize send operations.
     *
     * @dev This constant holds the hash of the string "AUTHORIZER_ROLE".
     */
    bytes32 public constant AUTHORIZER_ROLE = LibRoles.AUTHORIZER_ROLE;

    /**
     * @notice The Access Control identifier for the Salvager Role.
     * An account with "SALVAGE_ROLE" can salvage tokens and gas.
     *
     * @dev This constant holds the hash of the string "SALVAGE_ROLE".
     */
    bytes32 public constant SALVAGE_ROLE = LibRoles.SALVAGE_ROLE;

    /**
     * @notice The Access Control identifier for the Embargo Role.
     * An account with "EMBARGO_ROLE" can salvage tokens and gas.
     *
     * @dev This constant holds the hash of the string "EMBARGO_ROLE".
     */
    bytes32 public constant EMBARGO_ROLE = LibRoles.EMBARGO_ROLE;

    // State variables
    IERC20F internal immutable innerToken;

    // Embargoed amounts by address
    EnumerableMap.AddressToUintMap internal _embargoLedger;

    // Events
    event EmbargoLock(address indexed recipient, bytes bError, uint256 amount);
    event EmbargoRelease(address indexed caller, address indexed embargoedAccount, address indexed _to, uint256 amount);

    /**
     * @dev Constructor for the OFTAdapter contract.
     * @param _token The address of the ERC-20 token to be adapted.
     * @param _lzEndpoint The LayerZero endpoint address.
     * @param defaultAdmin The default admin for the contract.
     * @param _delegate The delegate for the contract. This account will be able to set configs, on behalf of the
     *                  OApp, directly on the Endpoint contract. It will also receive the CONTRACT_ADMIN_ROLE.
     */
    constructor(
        address _token,
        address _lzEndpoint,
        address defaultAdmin,
        address _delegate
    )
        OFTCore(IERC20Metadata(_token).decimals(), _lzEndpoint, _delegate)
        EIP712("WusdOFTAdapter", "1")
        AccessRegistrySubscriptionCapable(address(0))
        RoleBasedOwnable()
        PauseCapable()
    {
        innerToken = IERC20F(_token);
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(CONTRACT_ADMIN_ROLE, _delegate);
    }

    /**
     * @dev Retrieves the domain separator for the EIP712 signature required for the OFTSendAuthorization.
     * @return The domain separator for the EIP712 signature.
     */
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @notice Indicates whether the OFT contract requires approval of the 'token()' to send.
     * @return requiresApproval Needs approval of the underlying token implementation.
     *
     * @dev In the case of default OFTAdapter, approval is required.
     * @dev In non-default OFTAdapter contracts with something like mint and burn privileges, it would NOT need approval.
     */
    function approvalRequired() external pure virtual returns (bool) {
        return true;
    }

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {sendWithAuthorization}.
     *
     * Every successful call to {sendWithAuthorization} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     * 
     * NOTE: This override DOES NOT return the full key-and-nonce, like the parent contract {NoncesKeyed} does,
     * but only the nonce.
     * 
     * @param owner The address of the owner (i.e. an authorizer) to get the nonce for.
     * @param key The key to get the nonce for. It is an `uint192` representation of the `sender` address.
     * @return nonce Returns the next unused nonce for an address and key.
     */
    function nonces(address owner, uint192 key) public view virtual override(IWusdOFTAdapter, NoncesKeyed) returns (uint256) {
        uint256 keyAndNonce = super.nonces(owner, key);
        // This line extracts the nonce portion from keyAndNonce. In NoncesKeyed.sol, the nonce is stored
        // in the lower 64 bits of the uint256, while the key is stored in the upper 192 bits.
        // We use a bitmask to isolate the nonce portion and discard the key portion.
        return keyAndNonce & 0xFFFFFFFFFFFFFFFF;
    }

    /**
     * @dev Retrieves the address of the underlying ERC20 implementation.
     * @return The address of the adapted ERC-20 token.
     *
     * @dev In the case of OFTAdapter, address(this) and erc20 are NOT the same contract.
     */
    function token() public view returns (address) {
        return address(innerToken);
    }

    /**
     * @dev Locks tokens from the sender's specified balance in this contract.
     * @param _from The address to debit from.
     * @param _amountLD The amount of tokens to send in local decimals.
     * @param _minAmountLD The minimum amount to send in local decimals.
     * @param _dstEid The destination chain ID.
     * @return amountSentLD The amount sent in local decimals.
     * @return amountReceivedLD The amount received in local decimals on the remote.
     *
     * @dev msg.sender will need to approve this _amountLD of tokens to be locked inside of the contract.
     * @dev WARNING: The default OFTAdapter implementation assumes LOSSLESS transfers, ie. 1 token in, 1 token out.
     * IF the 'innerToken' applies something like a transfer fee, the default will NOT work...
     * a pre/post balance check will need to be done to calculate the amountReceivedLD.
     */
    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal virtual override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);
        // @dev Collect and Burn tokens by moving them into this contract from the caller.
        IERC20(address(innerToken)).safeTransferFrom(_from, address(this), amountSentLD);
        innerToken.burn(amountSentLD);
    }

    /**
     * @dev Credits tokens to the specified address.
     * @param _to The address to credit the tokens to.
     * @param _amountLD The amount of tokens to credit in local decimals.
     * @dev _srcEid The source chain ID.
     * @return amountReceivedLD The amount of tokens ACTUALLY received in local decimals.
     *
     * @dev WARNING: The default OFTAdapter implementation assumes LOSSLESS transfers, ie. 1 token in, 1 token out.
     * IF the 'innerToken' applies something like a transfer fee, the default will NOT work...
     * a pre/post balance check will need to be done to calculate the amountReceivedLD.
     */
    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 /*_srcEid*/
    ) internal virtual override returns (uint256 amountReceivedLD) {
        // @dev Mint and Send the tokens and transfer to the recipient.s
        innerToken.mint(address(this), _amountLD);
        (bool creditSuccess, bytes memory cRevert) = tryTransfer(_to, _amountLD);
        if (!creditSuccess) {
            (, uint256 currentEmbargo) = _embargoLedger.tryGet(_to);
            _embargoLedger.set(_to, currentEmbargo + _amountLD);
            emit EmbargoLock(_to, cRevert, _amountLD);
        }
        return _amountLD;
    }

    /**
     * @notice Executes the send operation.
     * @dev Executes the send operation.
     *
     * Calling Conditions:
     * - The contract is not paused. (checked in _requireHasAccess)
     * - The caller has access according to the `accessRegistry`.
     *
     * @param _sendParam The parameters for the send operation.
     * @param _fee The calculated fee for the send() operation.
     *   - nativeFee: The native fee.
     *   - lzTokenFee: The lzToken fee.
     * @param _refundAddress The address to receive any excess funds.
     * @return msgReceipt The receipt for the send operation.
     * MessagingReceipt: LayerZero msg receipt
     *   - guid: The unique identifier for the sent message.
     *   - nonce: The nonce of the sent message.
     *   - fee: The LayerZero fee incurred for the message.
     * @return oftReceipt The OFT receipt information.
     */
    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable virtual override returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) {
        _requireHasAccess(_msgSender());
        return _send(_sendParam, _fee, _refundAddress);
    }

    /**
     * @notice This function allows any user to send tokens by providing an authorization signature
     *
     * @dev The user provides the `OFTSendAuthorization` data (which includes the `SendParam` data). Additionally,
     * the user provides a EIP-712 signature of the `OFTSendAuthorization` data, which must come from an account
     * that has currently holds the AUTHORIZER_ROLE.
     *
     * Calling Conditions:
     * - The contract is not paused.
     * - The account that created the authorization signature:
     *   - has the `AUTHORIZER_ROLE`, and
     *   - matches the `authorizer` address listed in the `OFTSendAuthorization` data
     * - The `sender` address listed in the `OFTSendAuthorization` data matches the caller of this function.
     * - The deadline has not passed.
     * - The nonce has not been used.
     *
     * @param authorization The `OFTSendAuthorization` data.
     * @param v The recovery identifier (v), in the context of EIP-712
     * @param r The r component of the ECDSA signature, representing the first 32 bytes of the signature.
     * @param s The s component of the ECDSA signature, representing the second 32 bytes of the signature.
     * @param fee The calculated fee for the send() operation.
     * @param refundAddress The address to receive any excess funds.
     */
    function sendWithAuthorization(
        OFTSendAuthorization calldata authorization,
        uint8 v,
        bytes32 r,
        bytes32 s,
        MessagingFee calldata fee,
        address refundAddress
    )
        external payable virtual override whenNotPaused
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        // Verify deadline
        require(block.timestamp <= authorization.deadline, LibErrors.ExpiredAuthorization());
        // Verify sender matches caller
        require(authorization.sender == _msgSender(), "WusdOFTAdapter: unauthorized sender");

        // Verify authorizer has access
        _checkRole(AUTHORIZER_ROLE, authorization.authorizer);

        // Create EIP-712 struct hash
        bytes32 sendParamsHash = keccak256(
            abi.encode(
                SEND_PARAM_TYPEHASH,
                authorization.sendParams.dstEid,
                authorization.sendParams.to,
                authorization.sendParams.amountLD,
                authorization.sendParams.minAmountLD,
                keccak256(authorization.sendParams.extraOptions),
                keccak256(authorization.sendParams.composeMsg),
                keccak256(authorization.sendParams.oftCmd)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                SEND_AUTHORIZATION_TYPEHASH,
                authorization.authorizer,
                authorization.sender,
                sendParamsHash,
                authorization.deadline,
                authorization.nonce
            )
        );
        bytes32 typedDataHash = _hashTypedDataV4(structHash);
        // Verify signature is from authorizer
        address signer = ECDSA.recover(typedDataHash, v, r, s);
        require(signer == authorization.authorizer, "WusdOFTAdapter: invalid authorization");

        // Checks-Effects
        _useCheckedNonce(authorization.authorizer, addressToNonceKey(authorization.sender), authorization.nonce);

        // Execute send
        return _send(authorization.sendParams, fee, refundAddress);
    }

    /**
     * @notice A function that returns the amount of `innerToken` currently embargoed on the contract
     * for a given account.
     *
     * @dev This function will return 0 if the account has no embargoed amount.
     * @param _account The account to check for an embargoed amount.
     */
    function embargoedBalance(address _account) external view returns (uint256) {
        (, uint256 embargoAmount) = _embargoLedger.tryGet(_account);
        return embargoAmount;
    }

    /**
     * @notice A function that returns a list of accounts that currently have an embargoed balance on the contract.
     *
     * @dev This function return an array containing all the keys of the `_embargoLedger` mapping.
     *
     * WARNING: DO NOT call this function from another smart contract. Instead, check if an account has an embargoed
     * balance on the contract by calling `embargoedBalance` directly.
     *
     * "This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. (...) Using it as part of a
     * state-changing function may render the function uncallable if the map grows to a point where [the operation
     * would consume too] much gas to fit in a block."
     * - openzeppelin-contracts/utils/structs/EnumerableMap.sol
     */
    function embargoedAccounts() external view returns (address[] memory) {
        return _embargoLedger.keys();
    }

    /**
     * @notice A function used to withdraw `innerToken` balance currently embargoed by the contract,
     * to a specified `_to` address. The entirety of the `embargoed` account's balance is withdrawn.
     * @dev Calling Conditions:
     *
     * - `embargoed` account has a non-zero balance in `_embargoLedger`.
     * - the caller has the `EMBARGO_ROLE`, if the recipient `_to` is not the `embargoed` account.
     * - the contract is not paused.
     *
     * @param embargoed The account that currently has an embargoed balance on this contract.
     * @param _to The address to send the tokens to.
     */
    function recoverEmbargo(address embargoed, address _to) external {
        _recoverEmbargo(embargoed, _to);
    }

    /**
     * @notice A function used to withdraw `innerToken` balance currently embargoed by the contract to
     * the `embargoed` account. Used in the scenario where the `embargoed` account is now capable/allowed
     * to hold a balance of `innerToken`, hence the function has no access control.
     * @dev Calling Conditions:
     *
     * - the calling account has a non-zero balance in `_embargoLedger`.
     * - the contract is not paused.
     *
     * @param embargoed The account that currently has an embargoed balance on this contract.
     */
    function releaseEmbargo(address embargoed) external {
        _recoverEmbargo(embargoed, embargoed);
    }

    /**
     * @dev Converts an address into a nonce key by casting it to uint192.
     * Since an Ethereum address is 20 bytes (160 bits), it fits within uint192 (24 bytes/192 bits).
     * @param addr The address to convert into a nonce key
     * @return key The uint192 nonce key derived from the address
     */
    function addressToNonceKey(address addr) public pure returns (uint192) {
        return uint192(uint160(addr));
    }

    /**
     * @dev Internal function to execute the recover embargo operation.
     * @param embargoed The account that currently has an embargoed balance on this contract.
     * @param _to The address to send the tokens to.
     */
    function _recoverEmbargo(address embargoed, address _to) internal {
        if (embargoed != _to) {
            _authorizeEmbargo();
        }
        (bool embargoExists, uint256 embargoAmount) = _embargoLedger.tryGet(embargoed);
        bool embargoPurged = _embargoLedger.remove(embargoed);
        require(embargoExists && embargoPurged, LibErrors.NoBalance());

        emit EmbargoRelease(_msgSender(), embargoed, _to, embargoAmount);

        _withdrawERC20(IERC20(address(innerToken)), _to, embargoAmount);
    }

    /**
     * @notice Tries to transfer tokens to the specified address.
     * @param _to The address to send the tokens to.
     * @param _amountLD The amount of tokens to send.
     * @return A boolean indicating whether the token transfer was successful.
     *
     * @dev Returns false when there is a revert in the low level call or `transfer` returns false
     *
     * Calling Conditions:
     * - `innerToken` MUST be a contract with code. This is because if the low level call does not revert
     *   (i.e. success == true) for whatever reason (empty code included) and the return data is not exactly
     *   `false`, it is assumed that the transfer succeeded.
     */
    function tryTransfer(address _to, uint256 _amountLD) internal returns (bool, bytes memory) {
        // This is a variant of SafeERC20.safeTransfer
        (bool success, bytes memory returndata) = address(innerToken).call(
            abi.encodeCall(innerToken.transfer, (_to, _amountLD))
        );
        // case: non-reverting calls but ERC20 transfer function returns false
        if (success && returndata.length != 0 && !abi.decode(returndata, (bool))) {
            return (false, "");
        } else if (!success) {
            // case: call reverted
            return (false, returndata); // returndata is the revert reason
        }
        // documented warning case: success == `true` and returndata is not exactly `false`
        // happy case: success == `true` and returndata == `true`
        return (true, "");
    }

    /**
     * @notice This is a function that applies a role check to guard operations originally dependent on `onlyOwner`.
     *
     * @dev Reverts when the caller does not have the "CONTRACT_ADMIN_ROLE".
     *
     * Calling Conditions:
     *
     * - Only the "CONTRACT_ADMIN_ROLE" can execute.
     */
    /* solhint-disable no-empty-blocks */
    function _checkOwner() internal view virtual override(Ownable, RoleBasedOwnable) onlyRole(CONTRACT_ADMIN_ROLE) {}

    /**
     * @notice This is a function that applies any validations required to allow Access Registry updates.
     *
     * @dev Reverts when the caller does not have the "CONTRACT_ADMIN_ROLE".
     *
     * Calling Conditions:
     *
     * - Only the "CONTRACT_ADMIN_ROLE" can execute.
     * - {ERC20F} is not paused.
     */
    /* solhint-disable no-empty-blocks */
    function _authorizeAccessRegistryUpdate() internal virtual override whenNotPaused onlyRole(CONTRACT_ADMIN_ROLE) {}

    /**
	 * @notice This is a function that applies any validations required to allow embargo operations.
	 *
	 * @dev Reverts when the caller does not have the "EMBARGO_ROLE".
     * 
     * Calling Conditions:
     * 
     * - Only the "EMBARGO_ROLE" can execute.
     * - The contract is not paused.
     * 
	/* solhint-disable no-empty-blocks */
    function _authorizeEmbargo() internal virtual whenNotPaused onlyRole(EMBARGO_ROLE) {}

    /**
     * @notice This is a function that applies any validations required to allow Pause operations (like pause
     *         or unpause) to be executed.
     *
     * @dev Reverts when the caller does not have the "PAUSER_ROLE".
     *
     * Calling Conditions:
     *
     * - Only the "PAUSER_ROLE" can execute.
     */
    /* solhint-disable no-empty-blocks */
    function _authorizePause() internal virtual override onlyRole(PAUSER_ROLE) {}

    /**
     * @notice This is a function that applies any validations required to allow Role Access operation (like grantRole or revokeRole ) to be executed.
     *
     * @dev Reverts when the {ERC20F} contract is paused.
     *
     * Calling Conditions:
     *
     * - {ERC20F} is not paused.
     */
    /* solhint-disable no-empty-blocks */
    function _authorizeRoleManagement() internal virtual override whenNotPaused {}

    /**
     * @notice This is a function that applies any validations required to allow salvage operations (like salvageGas).
     *
     * @dev Reverts when the caller does not have the "SALVAGE_ROLE".
     *
     * Calling Conditions:
     *
     * - Only the "SALVAGE_ROLE" can execute.
     * - The contract is not paused.
     */
    /* solhint-disable no-empty-blocks */
    function _authorizeSalvage() internal virtual whenNotPaused onlyRole(SALVAGE_ROLE) {}

    /**
     * @notice This is a function that applies any validations required to allow salvageERC20.
     *
     * It adds a check to ensure that the `salvagedToken` is not the same as `innerToken`. The `salvageERC20` function
     * can't be used to salvage the `innerToken`, as only accounts with `EMBARGO_ROLE` can manage the `innerToken`
     * embargoed on this contract.
     *
     * @dev Reverts:
     *  - if `salvagedToken` is the same as `innerToken`
     *  - as per `_authorizeSalvage()`
     *
     * @param salvagedToken The address of the token being salvaged.
     */
    function _authorizeSalvageERC20(address salvagedToken) internal virtual override {
        _authorizeSalvage();
        if (salvagedToken == address(innerToken)) {
            revert LibErrors.UnauthorizedTokenManagement();
        }
    }

    /**
     * @notice This is a function that applies any validations required to allow salvageGas.
     *
     * @dev Reverts as per `_authorizeSalvage()`.
     */
    function _authorizeSalvageGas() internal virtual override {
        _authorizeSalvage();
    }

    /**
     * @notice This function checks that an account can have access to the OApp endpoints.
     * The function will revert if the account does not have access.
     *
     * @param account The address to check for access.
     */
    function _requireHasAccess(address account) internal view virtual whenNotPaused {
        if (address(accessRegistry) != address(0)) {
            if (!accessRegistry.hasAccess(account, _msgSender(), _msgData())) {
                revert LibErrors.AccountUnauthorized(account);
            }
        }
    }
}
