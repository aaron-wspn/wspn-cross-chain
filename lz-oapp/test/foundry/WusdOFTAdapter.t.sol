// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { TestHelperOz5, EndpointV2 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

// OApp imports
import { IOAppOptionsType3, EnforcedOptionParam } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import { LibErrors } from "../../contracts/library/LibErrors.sol";
import { IOFT, SendParam, MessagingFee } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import "../../contracts/interfaces/IERC20F.sol";
import { IWusdOFTAdapter } from "../../contracts/interfaces/IWusdOFTAdapter.sol";
import "../../contracts/WusdOFTAdapter.sol";
import "../../contracts/mocks/AccessRegistryMock.sol";
import { ERC20Mock, IERC20Errors } from "../mocks/ERC20Mock.sol";

// Build permit signature
bytes32 constant PERMIT_TYPEHASH = keccak256(
    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
);

uint128 constant lzReceiveGasLimit = 300_000; // in gas units (wei)

contract WusdOFTAdapterTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    // Token and Adapter declarations
    ERC20Mock internal aToken;
    ERC20Mock internal bToken;
    uint8 internal immutable aTokenDecimals = 18;
    uint8 internal immutable bTokenDecimals = 6;
    WusdOFTAdapter public aOFTAdapter;
    WusdOFTAdapter public bOFTAdapter;
    AccessRegistryMock public accessRegistryOAppA;
    // Endpoints identifiers
    uint32 private aEid = 1;
    uint32 private bEid = 2;
    // Common account addresses and keys
    address public defaultAdmin = makeAddr("defaultAdmin");
    address public contractAdmin = makeAddr("contractAdmin");
    address public pauser = makeAddr("pauser");
    address public salvageAdmin = makeAddr("salvageAdmin");
    address public embargoAdmin = makeAddr("embargoAdmin");
    address public userA;
    uint256 private userAPrivateKey;
    address public userB = makeAddr("userB");
    address public authorizer;
    uint256 private authorizerPrivateKey;
    address public unauthorizedUser;
    uint256 private unauthorizedUserPrivateKey;

    uint256 internal initialBalance0Decimals = 1000;

    // Common constants used for send operations in tests
    uint256 constant DEFAULT_TOKENS_TO_SEND = 580; // in A-token units
    uint256 constant FIFTEEN_MINUTES = 60 * 15;

    function setUp() public virtual override {
        (userA, userAPrivateKey) = makeAddrAndKey("userA");
        (authorizer, authorizerPrivateKey) = makeAddrAndKey("authorizer");
        (unauthorizedUser, unauthorizedUserPrivateKey) = makeAddrAndKey("unauthorizedUser");
        vm.deal(userA, 100 ether);
        vm.deal(userB, 100 ether);
        vm.deal(authorizer, 100 ether);
        vm.deal(unauthorizedUser, 1 ether);
        // Deploy mock tokens
        aToken = new ERC20Mock("Token on Chain A", "TOKEN", aTokenDecimals);
        bToken = new ERC20Mock("Token on Chain B", "TOKEN", bTokenDecimals);
        // Deploy mock access registry
        accessRegistryOAppA = new AccessRegistryMock();

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Deploy Adapters
        aOFTAdapter = new WusdOFTAdapter(
            address(aToken), // token address
            address(endpoints[aEid]), // mock LZ endpoint
            defaultAdmin, // default admin
            contractAdmin // delegate (gets CONTRACT_ADMIN_ROLE)
        );
        bOFTAdapter = new WusdOFTAdapter(
            address(bToken), // token address
            address(endpoints[bEid]), // mock LZ endpoint
            defaultAdmin, // default admin
            contractAdmin // delegate (gets CONTRACT_ADMIN_ROLE)
        );
        // config and wire the oft adapters
        address[] memory ofts = new address[](2);
        ofts[0] = address(aOFTAdapter);
        ofts[1] = address(bOFTAdapter);
        vm.startPrank(contractAdmin);
        wireOApps(ofts);
        vm.stopPrank();
        // Setup roles
        vm.startPrank(defaultAdmin);
        aOFTAdapter.grantRole(LibRoles.AUTHORIZER_ROLE, authorizer);
        aOFTAdapter.grantRole(LibRoles.PAUSER_ROLE, pauser);
        aOFTAdapter.grantRole(LibRoles.EMBARGO_ROLE, embargoAdmin);
        bOFTAdapter.grantRole(LibRoles.AUTHORIZER_ROLE, authorizer);
        bOFTAdapter.grantRole(LibRoles.PAUSER_ROLE, pauser);
        bOFTAdapter.grantRole(LibRoles.EMBARGO_ROLE, embargoAdmin);
        vm.stopPrank();

        // Mint tokens to userA
        aToken.mint(userA, initialBalance0Decimals * 10 ** aTokenDecimals);

        // Optionally: set adapter access registry on OFT Adapter A
        // vm.prank(contractAdmin);
        // aOFTAdapter.accessRegistryUpdate(address(accessRegistryOAppA));
    }

    /**********************
     *  HELPER FUNCTIONS  *
     **********************/

    /// @notice Creates a SendParam struct with the given parameters.
    function _createSendParam(
        uint32 _dstEid,
        address _to,
        uint256 _amountLD,
        uint256 _minAmountLD
    ) internal pure returns (SendParam memory) {
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(lzReceiveGasLimit, 0);
        return SendParam(_dstEid, addressToBytes32(_to), _amountLD, _minAmountLD, options, "", "");
    }

    /// @notice Creates an authorization struct to be used for sendWithAuthorization.
    function _createAuthorization(
        address _authorizer,
        address _sender,
        SendParam memory _sendParam,
        uint256 _deadline
    ) internal view returns (IWusdOFTAdapter.OFTSendAuthorization memory) {
        return
            IWusdOFTAdapter.OFTSendAuthorization({
                authorizer: _authorizer,
                sender: _sender,
                sendParams: _sendParam,
                deadline: _deadline,
                nonce: aOFTAdapter.nonces(_authorizer)
            });
    }

    /// @notice Calculates the tokens received on destination considering the decimal conversion.
    function _calculateTokensToReceive(uint256 sendAmount) internal pure returns (uint256) {
        uint256 decimalConversionRate = 10 ** (aTokenDecimals - bTokenDecimals);
        return sendAmount / decimalConversionRate;
    }

    /// @notice Approves tokens and executes a normal send (without authorization).
    function _approveAndExecuteSend(
        address _sender,
        uint32 _dstEid,
        address _recipient,
        uint256 _amountLD
    ) internal returns (MessagingFee memory fee) {
        SendParam memory sendParam = _createSendParam(_dstEid, _recipient, _amountLD, _amountLD);
        fee = aOFTAdapter.quoteSend(sendParam, false);
        vm.prank(_sender);
        aToken.approve(address(aOFTAdapter), _amountLD);
        vm.prank(_sender);
        aOFTAdapter.send{ value: fee.nativeFee }(sendParam, fee, _sender);
        verifyPackets(_dstEid, addressToBytes32(address(bOFTAdapter)));
        return fee;
    }

    /// @notice Executes a sendWithAuthorization flow:
    /// 1. Prepares send parameters and authorization.
    /// 2. Signs the authorization message.
    /// 3. Approves tokens.
    /// 4. Executes sendWithAuthorization.
    /// 5. Verifies that packets are queued for the destination.
    function _approveAndExecuteSendWithAuth(
        address _sender,
        address _recipient,
        uint256 _amountLD,
        address _signer,
        uint256 _signerPrivateKey,
        uint256 _deadline
    ) internal returns (MessagingFee memory fee) {
        SendParam memory sendParam = _createSendParam(bEid, _recipient, _amountLD, _amountLD);
        IWusdOFTAdapter.OFTSendAuthorization memory auth = _createAuthorization(_signer, _sender, sendParam, _deadline);
        (uint8 v, bytes32 r, bytes32 s) = _createAuthorizationSignature(auth, _signerPrivateKey);
        fee = aOFTAdapter.quoteSend(sendParam, false);
        vm.prank(_sender);
        aToken.approve(address(aOFTAdapter), _amountLD);
        vm.prank(_sender);
        aOFTAdapter.sendWithAuthorization{ value: fee.nativeFee }(auth, v, r, s, fee, _sender);
        verifyPackets(bEid, addressToBytes32(address(bOFTAdapter)));
        return fee;
    }

    /// @notice Verifies the expected A- and B-token balances of a user.
    function _verifyBalances(address _holder, uint256 _expectedABalance, uint256 _expectedBBalance) internal view {
        assertEq(aToken.balanceOf(_holder), _expectedABalance, "A token balance mismatch");
        assertEq(bToken.balanceOf(_holder), _expectedBBalance, "B token balance mismatch");
    }

    function test_constructor() public view {
        assertEq(address(aOFTAdapter.token()), address(aToken));
        assertEq(address(aOFTAdapter.endpoint()), address(endpoints[aEid]));
        EndpointV2 aEndpoint = EndpointV2(address(endpoints[aEid]));
        assertEq(aEndpoint.delegates(address(aOFTAdapter)), address(contractAdmin));
        assertEq(address(aOFTAdapter.accessRegistry()), address(0));
        assertEq(aOFTAdapter.owner(), address(0));
        assertEq(aOFTAdapter.paused(), false);
        assertTrue(aOFTAdapter.hasRole(LibRoles.DEFAULT_ADMIN_ROLE, defaultAdmin));
        assertTrue(aOFTAdapter.hasRole(LibRoles.CONTRACT_ADMIN_ROLE, contractAdmin));
    }

    function test_sendTokensToSelfUserA() public {
        // set adapter access registry on OFT Adapter A
        vm.prank(contractAdmin);
        aOFTAdapter.accessRegistryUpdate(address(accessRegistryOAppA));
        // grant access to the userA
        accessRegistryOAppA.setAccess(userA, true);

        uint256 initialBalance = aToken.balanceOf(userA);
        uint256 tokensToSend = 580 * 10 ** aTokenDecimals;
        uint256 tokensToReceive = _calculateTokensToReceive(tokensToSend);
        // Check initial balances
        _verifyBalances(userA, initialBalance, 0);
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0);

        _approveAndExecuteSend(userA, bEid, userA, tokensToSend);

        _verifyBalances(userA, initialBalance - tokensToSend, tokensToReceive);
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0); // tokens burned on source chain
    }

    function test_sendTokensToSelfAccessRegistryFree() public {
        // deny access to the userA (but don't link the access registry to the OFT Adapter)
        accessRegistryOAppA.setAccess(userA, false);
        uint256 initialBalance = aToken.balanceOf(userA);
        uint256 tokensToSend = 580 * 10 ** aTokenDecimals;
        uint256 tokensToReceive = _calculateTokensToReceive(tokensToSend);
        // initial checks
        assertTrue(initialBalance >= tokensToSend, "Test validity: userA has sufficient balance");
        assertEq(address(aOFTAdapter.accessRegistry()), address(0)); // no access registry linked to the OFT Adapter
        assertFalse(accessRegistryOAppA.hasAccess(userA, address(0), "0x")); // userA is denied access in the access registry

        _verifyBalances(userA, initialBalance, 0);
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0);

        _approveAndExecuteSend(userA, bEid, userA, tokensToSend);

        _verifyBalances(userA, initialBalance - tokensToSend, tokensToReceive);
    }

    function test_RevertWhen_SendCallerNotInAllowlist() public {
        // set adapter access registry on OFT Adapter A
        vm.prank(contractAdmin);
        aOFTAdapter.accessRegistryUpdate(address(accessRegistryOAppA));
        // deny access to the unauthorized user (even though the default response is false)
        accessRegistryOAppA.setAccess(unauthorizedUser, false);

        uint256 tokensToSend = aToken.balanceOf(userA) / 2;

        // Transfer tokens so that unauthorizedUser holds some tokens.
        vm.prank(userA);
        aToken.transfer(unauthorizedUser, tokensToSend);

        SendParam memory sendParam = _createSendParam(bEid, unauthorizedUser, tokensToSend, tokensToSend);
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);

        vm.prank(unauthorizedUser);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.AccountUnauthorized.selector, unauthorizedUser));
        aOFTAdapter.send{ value: fee.nativeFee }(sendParam, fee, userA);
    }

    function test_RevertIf_SendWhilePaused() public {
        uint256 tokensToSend = DEFAULT_TOKENS_TO_SEND * 10 ** aTokenDecimals;
        vm.prank(pauser);
        aOFTAdapter.pause();

        SendParam memory sendParam = _createSendParam(bEid, userA, tokensToSend, tokensToSend);
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);

        vm.startPrank(userA);
        aToken.approve(address(aOFTAdapter), tokensToSend);

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        aOFTAdapter.send{ value: fee.nativeFee }(sendParam, fee, userA);
        vm.stopPrank();
    }

    // NOTE: This should be part of the Documentation, noting that such small amounts are not supported.
    // Failure: Sending a dust amount (precision loss causing a slippage error).
    function test_RevertWhen_SendDustAmount() public {
        uint256 tokensThatCanBeSent = 1 * 10 ** aTokenDecimals; // 1 token with decimals
        uint256 tokensThatCannotBeSent = 999_999; // mantissa (sharedDecimals = 6). `sharedDecimals` is
        // the minimum precision of the OFT Adapter.
        uint256 tokensToSend = tokensThatCanBeSent + tokensThatCannotBeSent;
        // example:
        // uint version for token with 12 decimals - 1 token = 10^12
        // 1_000_000_000_000
        //  {               }    <--- aTokenDecimals
        // 1_000_000_000_000
        //  {       }    <--- sharedDecimals
        // 1_000_000_000_000
        //          {       }            <--- aTokenDecimals **only** i.e. tokens that can't be sent without precision loss
        assertTrue(aToken.balanceOf(userA) > tokensToSend, "Insufficient balance for test");

        SendParam memory sendParam = _createSendParam(bEid, userA, tokensToSend, tokensToSend);

        // Expect quoteSend to revert with the slippage error.
        vm.expectRevert(abi.encodeWithSelector(IOFT.SlippageExceeded.selector, tokensThatCanBeSent, tokensToSend));
        aOFTAdapter.quoteSend(sendParam, false);
        // NOTE: SlippageExceeded is experienced on both quoteSend and send

        // Approve tokens and then test that the send call also reverts
        vm.startPrank(userA);
        aToken.approve(address(aOFTAdapter), tokensToSend);
        vm.expectRevert(abi.encodeWithSelector(IOFT.SlippageExceeded.selector, tokensThatCanBeSent, tokensToSend));
        aOFTAdapter.send(
            sendParam,
            MessagingFee({ nativeFee: 1 ether, lzTokenFee: 0 }), // NOTE: This is not the actual fee. This is a placeholder,
            // as the `quoteSend` call is expected to revert
            userA
        );
        vm.stopPrank();
    }

    function test_RevertWhen_SendInsufficientBalance() public {
        uint256 initialBalance = aToken.balanceOf(userA);
        uint256 tokensToSend = initialBalance * 2;
        assertTrue(initialBalance < tokensToSend, "Test validity: userA has sufficient balance");

        SendParam memory sendParam = _createSendParam(bEid, userA, tokensToSend, tokensToSend);
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);
        // couple more initial assertions
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0);
        _verifyBalances(userA, initialBalance, 0);

        vm.startPrank(userA);
        aToken.approve(address(aOFTAdapter), tokensToSend);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, userA, initialBalance, tokensToSend)
        );
        aOFTAdapter.send(sendParam, fee, userA);
        vm.stopPrank();

        // Confirm that balances remain unchanged.
        _verifyBalances(userA, initialBalance, 0);
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0);
    }

    function _createAuthorizationSignature(
        IWusdOFTAdapter.OFTSendAuthorization memory authorization,
        uint256 signerPrivateKey
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        // Hash the SendParam struct first
        bytes32 sendParamsStructHash = keccak256(
            abi.encode(
                aOFTAdapter.SEND_PARAM_TYPEHASH(),
                authorization.sendParams.dstEid,
                authorization.sendParams.to,
                authorization.sendParams.amountLD,
                authorization.sendParams.minAmountLD,
                keccak256(authorization.sendParams.extraOptions),
                keccak256(authorization.sendParams.composeMsg),
                keccak256(authorization.sendParams.oftCmd)
            )
        );
        bytes32 authorizationHash = keccak256(
            abi.encode(
                aOFTAdapter.SEND_AUTHORIZATION_TYPEHASH(),
                authorization.authorizer,
                authorization.sender,
                sendParamsStructHash,
                authorization.deadline,
                authorization.nonce
            )
        );
        bytes32 authorization712Digest = keccak256(
            abi.encodePacked("\x19\x01", aOFTAdapter.DOMAIN_SEPARATOR(), authorizationHash)
        );
        return vm.sign(signerPrivateKey, authorization712Digest);
    }

    function test_sendTokensWithAuthorization() public {
        // Set up access registry
        vm.prank(contractAdmin);
        aOFTAdapter.accessRegistryUpdate(address(accessRegistryOAppA)); // no need to add authorizer to the allowlist

        uint256 initialBalance = aToken.balanceOf(userA);
        uint256 tokensToSend = DEFAULT_TOKENS_TO_SEND * 10 ** aTokenDecimals;
        uint256 tokensToReceive = _calculateTokensToReceive(tokensToSend);

        // Verify initial balances
        _verifyBalances(userA, initialBalance, 0);
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0);
        assertEq(bToken.balanceOf(address(bOFTAdapter)), 0);
        _verifyBalances(authorizer, 0, 0);

        // Execute sendWithAuthorization (userA sends to themselves)
        _approveAndExecuteSendWithAuth(
            userA,
            userA,
            tokensToSend,
            authorizer,
            authorizerPrivateKey,
            block.timestamp + FIFTEEN_MINUTES
        );

        // Verify final balances have been updated appropriately
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0);
        assertEq(bToken.balanceOf(address(bOFTAdapter)), 0);
        _verifyBalances(userA, initialBalance - tokensToSend, tokensToReceive);
        _verifyBalances(authorizer, 0, 0);
        // Verify nonce updates
        assertEq(aOFTAdapter.nonces(userA), 0);
        assertEq(aOFTAdapter.nonces(authorizer), 1);
    }

    function test_sendWithAuthorizationToAnotherUser() public {
        // Set up access registry
        vm.prank(contractAdmin);
        aOFTAdapter.accessRegistryUpdate(address(accessRegistryOAppA)); // no need to add authorizer to the allowlist

        uint256 initialBalanceUserA = aToken.balanceOf(userA);
        uint256 tokensToSend = initialBalanceUserA;
        uint256 tokensToReceiveUserB = _calculateTokensToReceive(tokensToSend);

        // Verify initial balances
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0);
        assertEq(bToken.balanceOf(address(bOFTAdapter)), 0);
        _verifyBalances(userA, initialBalanceUserA, 0);
        _verifyBalances(userB, 0, 0);
        _verifyBalances(authorizer, 0, 0);

        _approveAndExecuteSendWithAuth(
            userA,
            userB,
            tokensToSend,
            authorizer,
            authorizerPrivateKey,
            block.timestamp + FIFTEEN_MINUTES
        );

        // Verify final balances have been updated appropriately
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0); // tokens burned on source chain
        assertEq(bToken.balanceOf(address(bOFTAdapter)), 0); // tokens minted on destination chain and sent to userA
        _verifyBalances(userA, 0, 0);
        _verifyBalances(userB, 0, tokensToReceiveUserB);
        _verifyBalances(authorizer, 0, 0);

        // Nonce checks
        assertEq(aOFTAdapter.nonces(userA), 0);
        assertEq(aOFTAdapter.nonces(authorizer), 1);
        assertEq(aOFTAdapter.nonces(userB), 0);
    }

    function test_RevertIf_SendWithAuthorizationWhilePaused() public {
        uint256 tokensToSend = DEFAULT_TOKENS_TO_SEND * 10 ** aTokenDecimals;
        vm.prank(pauser);
        aOFTAdapter.pause();

        SendParam memory sendParam = _createSendParam(bEid, userA, tokensToSend, tokensToSend);
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);

        IWusdOFTAdapter.OFTSendAuthorization memory auth = _createAuthorization(
            authorizer,
            userA,
            sendParam,
            block.timestamp + FIFTEEN_MINUTES
        );
        (uint8 v, bytes32 r, bytes32 s) = _createAuthorizationSignature(auth, authorizerPrivateKey);
        fee = aOFTAdapter.quoteSend(sendParam, false);
        vm.prank(userA);
        aToken.approve(address(aOFTAdapter), tokensToSend);

        vm.startPrank(userA);
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        aOFTAdapter.sendWithAuthorization{ value: fee.nativeFee }(auth, v, r, s, fee, userA);
        vm.stopPrank();
    }

    function test_RevertWhen_sendWithAuthorizationDeadlineExpired() public {
        uint256 tokensToSend = DEFAULT_TOKENS_TO_SEND * 10 ** aTokenDecimals;
        SendParam memory sendParam = _createSendParam(bEid, userA, tokensToSend, tokensToSend);
        // Create an authorization with an expired deadline.
        IWusdOFTAdapter.OFTSendAuthorization memory auth = _createAuthorization(
            authorizer,
            userA,
            sendParam,
            block.timestamp - 1
        );
        (uint8 v, bytes32 r, bytes32 s) = _createAuthorizationSignature(auth, authorizerPrivateKey);
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);

        vm.startPrank(userA);
        aToken.approve(address(aOFTAdapter), tokensToSend);

        vm.expectRevert(abi.encodeWithSelector(LibErrors.ExpiredAuthorization.selector));
        aOFTAdapter.sendWithAuthorization{ value: fee.nativeFee }(auth, v, r, s, fee, userA);
        vm.stopPrank();
    }

    function test_RevertIf_sendWithAuthorizationFromNonAuthorizer() public {
        // Set up access registry and add unauthorizedUser to the allowlist. However, unauthorizedUser
        // does not have the AUTHORIZER_ROLE
        vm.prank(contractAdmin);
        aOFTAdapter.accessRegistryUpdate(address(accessRegistryOAppA));
        accessRegistryOAppA.setAccess(unauthorizedUser, true);

        uint256 tokensToSend = DEFAULT_TOKENS_TO_SEND * 10 ** aTokenDecimals;
        SendParam memory sendParam = _createSendParam(bEid, userA, tokensToSend, tokensToSend);
        // Set up authorization using a signer who does not have the AUTHORIZER_ROLE. // NOTE: Add another test where unauthorizedUser will sign the authorization, and it is not authorized
        IWusdOFTAdapter.OFTSendAuthorization memory auth = _createAuthorization(
            unauthorizedUser,
            userA,
            sendParam,
            block.timestamp + FIFTEEN_MINUTES
        );
        (uint8 v, bytes32 r, bytes32 s) = _createAuthorizationSignature(auth, unauthorizedUserPrivateKey);
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);

        vm.startPrank(userA);
        aToken.approve(address(aOFTAdapter), tokensToSend);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorizedUser,
                LibRoles.AUTHORIZER_ROLE
            )
        );
        aOFTAdapter.sendWithAuthorization{ value: fee.nativeFee }(auth, v, r, s, fee, userA);
        vm.stopPrank();
    }
}
