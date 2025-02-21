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

/**
 * @title LibRoles
 * @dev Library containing role definitions used across the protocol
 */
library LibRoles {
    // Default admin role with id 0x00
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    // Contract admin role that can update the Access Registry and update OApp configurations
    bytes32 public constant CONTRACT_ADMIN_ROLE = keccak256("CONTRACT_ADMIN_ROLE");

    // Role that can pause the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Role that can authorize send operations
    bytes32 public constant AUTHORIZER_ROLE = keccak256("AUTHORIZER_ROLE");

    // Role that can salvage tokens and gas
    bytes32 public constant SALVAGE_ROLE = keccak256("SALVAGE_ROLE");

    // Role that can manage embargoed tokens
    bytes32 public constant EMBARGO_ROLE = keccak256("EMBARGO_ROLE");
}
