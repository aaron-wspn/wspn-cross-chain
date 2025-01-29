// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SendParam, MessagingFee, MessagingReceipt, OFTReceipt } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

interface IWusdOFTAdapter {

    struct OFTSendAuthorization {
        // Permit data
        address owner;
        address spender; 
        uint256 value;
        uint256 permitNonce;
        // Shared data
        uint256 deadline; // In this design, the deadline must match both the permit and the send authorization
        // Send parameters
        SendParam sendParams;
        uint256 nonce;
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    
    function SEND_AUTHORIZATION_TYPEHASH() external view returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function sendWithAuthorization(
        OFTSendAuthorization calldata authorization,
        // Permit signature
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS,
        // Authorization signature
        uint8 v,
        bytes32 r,
        bytes32 s,
        // Other params
        MessagingFee calldata fee,
        address refundAddress
    ) external payable returns (MessagingReceipt memory, OFTReceipt memory);

    // ... other events and functions
} 