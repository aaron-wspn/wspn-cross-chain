// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SendParam, MessagingFee, MessagingReceipt, OFTReceipt } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

interface IWusdOFTAdapter {

    struct OFTSendAuthorization {
        address authorizer; // The address that signed the authorization
        address sender; // The address that will be sending the tokens
        SendParam sendParams; // OFT Send parameters
        uint256 deadline; // Deadline for the authorization
        uint256 nonce; // Nonce to prevent replay
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function SEND_AUTHORIZATION_TYPEHASH() external view returns (bytes32);

    function nonces(address authorizer) external view returns (uint256);

    function sendWithAuthorization(
        OFTSendAuthorization calldata authorization,
        // Authorization signature
        uint8 v,
        bytes32 r,
        bytes32 s,
        // Other Send params
        MessagingFee calldata fee,
        address refundAddress
    ) external payable returns (MessagingReceipt memory, OFTReceipt memory);

}
