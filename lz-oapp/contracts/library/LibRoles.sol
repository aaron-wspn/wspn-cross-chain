// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LibRoles
 * @dev Library containing role definitions used across the protocol
 */
library LibRoles {
    // Default admin role with id 0x00
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    // Contract admin role that can update the Access Registry
    bytes32 public constant CONTRACT_ADMIN_ROLE = keccak256("CONTRACT_ADMIN_ROLE");

    // Role that can pause the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Role that can update OApp configurations
    bytes32 public constant OAPP_ADMIN_ROLE = keccak256("OAPP_ADMIN_ROLE");

    // Role that can salvage tokens and gas
    bytes32 public constant SALVAGE_ROLE = keccak256("SALVAGE_ROLE");

    // Role that can manage embargoed tokens
    bytes32 public constant EMBARGO_ROLE = keccak256("EMBARGO_ROLE");
}
