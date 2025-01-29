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
pragma solidity 0.8.27;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IAccessRegistry} from "../interfaces/IAccessRegistry.sol";
import {LibErrors} from "../library/LibErrors.sol";

/**
 * @title Access Registry Subscription Module
 * @author Fireblocks
 * @dev This abstract contract provides internal contract logic for subscribing to an Access Registry contract.
 */
abstract contract AccessRegistrySubscriptionCapable is Context {
	/// State

	/**
	 * @notice This field is the address of the {AccessRegistry} contract.
	 */
	IAccessRegistry public accessRegistry;

	/// Events

	/**
	 * @notice This event is emitted when the {AccessRegistry} contract address is updated.
	 * @dev This event is emitted by the {_updateAccessRegistry} function.
	 *
	 * @param caller The address of the account that updated the {AccessRegistry} contract address.
	 * @param oldAccessRegistry The address of the old {AccessRegistry} contract.
	 * @param newAccessRegistry The address of the new {AccessRegistry} contract.
	 */
	event AccessRegistryUpdated(
		address indexed caller,
		address indexed oldAccessRegistry,
		address indexed newAccessRegistry
	);

	/// Functions

	/**
	 * @notice This is a constructor function for the abstract contract.
	 * @dev `_accessRegistry` must either be the zero address or implement IAccessRegistry interface.
	 * @param _accessRegistry The address of the contract that implements {IAccessRegistry}.
	 */
	constructor(address _accessRegistry) {
		_accessRegistryUpdate(_accessRegistry);
	}

	/**
	 * @notice This is a function used to update `accessRegistry` field.
	 * @dev This function emits a {AccessRegistryUpdated} event as part of {_accessRegistryUpdate}
	 * when the access registry address is successfully updated.
	 *
	 * @param _accessRegistry The address of the contract that implements {IAccessRegistry}.
	 */
	function accessRegistryUpdate(address _accessRegistry) external virtual {
		_authorizeAccessRegistryUpdate();
		_accessRegistryUpdate(_accessRegistry);
	}

	/**
	 * @notice This function updates the address of the implementation of {IAccessRegistry} contract by updating the
	 * `accessRegistry` field.
	 *
	 * @dev For idempotency, the function will not update the `accessRegistry` field or emit an event, 
	 * 		if the given argument is the current `accessRegistry` address.
	 * @dev Calling Conditions:
	 * - `_accessRegistry` must either:
	 *  - be the zero address, or,
	 *  - implement IAccessRegistry interface
	 *
	 * @param _accessRegistry The address of the contract that implements {IAccessRegistry}.
	 */
	function _accessRegistryUpdate(address _accessRegistry) internal virtual {
		if (_accessRegistry == address(accessRegistry)) {
			return;
		}
		address oldRegistry = address(accessRegistry);

		if (_accessRegistry == address(0)) {
			accessRegistry = IAccessRegistry(address(0));
			emit AccessRegistryUpdated(_msgSender(), oldRegistry, address(0));
			return;
		}
		// Check if target is a contract
		if (_accessRegistry.code.length == 0) {
			revert LibErrors.InvalidImplementation();
		}
		
		// Try to call supportsInterface
		(bool success, bytes memory returnData) = _accessRegistry.staticcall(
			abi.encodeCall(IERC165.supportsInterface, (type(IAccessRegistry).interfaceId))
		);
		// Revert if call failed or returned false
		if (!success || !abi.decode(returnData, (bool))) {
			revert LibErrors.InvalidImplementation();
		}

		accessRegistry = IAccessRegistry(_accessRegistry);
		emit AccessRegistryUpdated(_msgSender(), oldRegistry, _accessRegistry);
	}

	/**
	 * @notice This function is designed to be overridden in inheriting contracts.
	 * @dev Override this function to implement RBAC control.
	 */
	function _authorizeAccessRegistryUpdate() internal virtual;
}
