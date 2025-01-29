// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../../contracts/interfaces/IAccessRegistry.sol";

contract AccessRegistryMock is IAccessRegistry {
    mapping(address => bool) private _hasAccess;
    bool private _defaultResponse;

    // Function to set default response for all checks
    function setDefaultResponse(bool response) external {
        _defaultResponse = response;
    }

    // Function to set specific account access
    function setAccess(address account, bool access) external {
        _hasAccess[account] = access;
    }

    function hasAccess(address account, address, bytes calldata) 
        external 
        view 
        override 
        returns (bool) 
    {
        return _hasAccess[account] || _defaultResponse;
    }

    	/**
	 * @notice Returns true if this contract implements the interface defined by `interfaceId`. See the corresponding
	 * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section] to learn more about
	 * how these ids are created.
	 *
	 * @dev This function verifies that the {AccessList} implements {IAccessRegistry} and parent interfaces.
	 * @param interfaceId The interface identifier, as specified in ERC-165
	 * @return `true` if the contract implements `interfaceID` , `false` otherwise
	 */
	function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
		return
			interfaceId == type(IAccessRegistry).interfaceId;
	}
} 
