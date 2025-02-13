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

contract WusdOFTAdapterTest is TestHelperOz5 {
    using OptionsBuilder for bytes;
    ERC20Mock internal aToken;
    ERC20Mock internal bToken;
    uint8 internal immutable aTokenDecimals = 18;
    uint8 internal immutable bTokenDecimals = 6;
    WusdOFTAdapter public aOFTAdapter;
    WusdOFTAdapter public bOFTAdapter;
    AccessRegistryMock public accessRegistryOAppA;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    address public defaultAdmin = makeAddr("defaultAdmin");
    address public contractAdmin = makeAddr("contractAdmin");
    address public oAppAdmin = makeAddr("oAppAdmin");
    address public pauser = makeAddr("pauser");
    address public salvageAdmin = makeAddr("salvageAdmin");
    address public embargoAdmin = makeAddr("embargoAdmin");
    address public userA;
    uint256 private userAPrivateKey;
    address public userB = makeAddr("userB");
    address public unauthorizedUser = makeAddr("unauthorizedUser");

    uint256 internal initialBalance0Decimals = 1000;

    function setUp() public virtual override {
        (userA, userAPrivateKey) = makeAddrAndKey("userA");
        vm.deal(userA, 100 ether);
        vm.deal(userB, 100 ether);
        vm.deal(unauthorizedUser, 1 ether);
        // Deploy mock token
        aToken = new ERC20Mock("Token on Chain A", "TOKEN", aTokenDecimals);
        bToken = new ERC20Mock("Token on Chain B", "TOKEN", bTokenDecimals);
        // Deploy mock access registry
        accessRegistryOAppA = new AccessRegistryMock();

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Deploy WusdOFTAdapter with necessary parameters
        aOFTAdapter = new WusdOFTAdapter(
            address(aToken), // token address
            address(endpoints[aEid]), // mock LZ endpoint
            defaultAdmin, // default admin
            oAppAdmin // delegate (gets OAPP_ADMIN_ROLE)
        );
        bOFTAdapter = new WusdOFTAdapter(
            address(bToken), // token address
            address(endpoints[bEid]), // mock LZ endpoint
            defaultAdmin, // default admin
            oAppAdmin // delegate (gets OAPP_ADMIN_ROLE)
        );
        // config and wire the ofts
        address[] memory ofts = new address[](2);
        ofts[0] = address(aOFTAdapter);
        ofts[1] = address(bOFTAdapter);
        vm.startPrank(oAppAdmin);
        wireOApps(ofts);
        vm.stopPrank();
        // Setup roles
        vm.startPrank(defaultAdmin);
        aOFTAdapter.grantRole(LibRoles.CONTRACT_ADMIN_ROLE, contractAdmin);
        aOFTAdapter.grantRole(LibRoles.PAUSER_ROLE, pauser);
        aOFTAdapter.grantRole(LibRoles.EMBARGO_ROLE, embargoAdmin);
        bOFTAdapter.grantRole(LibRoles.CONTRACT_ADMIN_ROLE, contractAdmin);
        bOFTAdapter.grantRole(LibRoles.PAUSER_ROLE, pauser);
        bOFTAdapter.grantRole(LibRoles.EMBARGO_ROLE, embargoAdmin);
        vm.stopPrank();

        // mint tokens
        aToken.mint(userA, initialBalance0Decimals * 10 ** aTokenDecimals);

        // set adapter access registry on OFT Adapter A
        // vm.prank(contractAdmin);
        // aOFTAdapter.accessRegistryUpdate(address(accessRegistryOAppA));
    }

    function test_constructor() public view {
        assertEq(address(aOFTAdapter.token()), address(aToken));
        assertEq(address(aOFTAdapter.endpoint()), address(endpoints[aEid]));
        EndpointV2 aEndpoint = EndpointV2(address(endpoints[aEid]));
        assertEq(aEndpoint.delegates(address(aOFTAdapter)), address(oAppAdmin));
        assertEq(address(aOFTAdapter.accessRegistry()), address(0));
        assertEq(aOFTAdapter.owner(), address(0));
        assertEq(aOFTAdapter.paused(), false);
        assertTrue(aOFTAdapter.hasRole(LibRoles.DEFAULT_ADMIN_ROLE, defaultAdmin));
        assertTrue(aOFTAdapter.hasRole(LibRoles.OAPP_ADMIN_ROLE, oAppAdmin));
    }

    function test_sendTokensToSelfUserA() public {
        // set adapter access registry on OFT Adapter A
        vm.prank(contractAdmin);
        aOFTAdapter.accessRegistryUpdate(address(accessRegistryOAppA));
        // grant access to the userA
        accessRegistryOAppA.setAccess(userA, true);
        uint256 initialBalance = aToken.balanceOf(userA);
        uint256 tokensToSend = 580 * 10 ** aTokenDecimals;
        uint256 decimalConversionRate = 10 ** (aTokenDecimals - bTokenDecimals);
        uint256 tokensToReceive = tokensToSend / decimalConversionRate;
        assertTrue(initialBalance >= tokensToSend); // test validity check

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(300000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(userA),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);

        assertEq(aToken.balanceOf(userA), initialBalance);
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0);
        assertEq(bToken.balanceOf(userA), 0);

        vm.prank(userA);
        aToken.approve(address(aOFTAdapter), tokensToSend);

        vm.prank(userA);
        aOFTAdapter.send{ value: fee.nativeFee }(sendParam, fee, userA);
        verifyPackets(bEid, addressToBytes32(address(bOFTAdapter)));

        assertEq(aToken.balanceOf(userA), initialBalance - tokensToSend);
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0); // tokens burned on source chain
        assertEq(bToken.balanceOf(userA), tokensToReceive);
    }

    function test_sendTokensToSelfAccessRegistryFree() public {
        // deny access to the userA (but don't link the access registry to the OFT Adapter)
        accessRegistryOAppA.setAccess(userA, false);
        uint256 initialBalance = aToken.balanceOf(userA);
        uint256 tokensToSend = 580 * 10 ** aTokenDecimals;
        uint256 decimalConversionRate = 10 ** (aTokenDecimals - bTokenDecimals);
        uint256 tokensToReceive = tokensToSend / decimalConversionRate;
        assertTrue(initialBalance >= tokensToSend); // test validity check
        assertEq(address(aOFTAdapter.accessRegistry()), address(0)); // no access registry linked to the OFT Adapter
        assertFalse(accessRegistryOAppA.hasAccess(userA, address(0), "0x")); // userA is denied access in the access registry

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(300000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(userA),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);

        assertEq(aToken.balanceOf(userA), initialBalance);
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0);
        assertEq(bToken.balanceOf(userA), 0);

        vm.prank(userA);
        aToken.approve(address(aOFTAdapter), tokensToSend);

        vm.prank(userA);
        aOFTAdapter.send{ value: fee.nativeFee }(sendParam, fee, userA);
        verifyPackets(bEid, addressToBytes32(address(bOFTAdapter)));

        assertEq(aToken.balanceOf(userA), initialBalance - tokensToSend); // tokens sent
        assertEq(bToken.balanceOf(userA), tokensToReceive); // tokens received
    }

    function test_RevertWhen_SendCallerNotInAllowlist() public {
        // set adapter access registry on OFT Adapter A
        vm.prank(contractAdmin);
        aOFTAdapter.accessRegistryUpdate(address(accessRegistryOAppA));
        // deny access to the unauthorized user (even though the default response is false)
        accessRegistryOAppA.setAccess(unauthorizedUser, false);
        uint256 initialBalance = aToken.balanceOf(userA);
        // give half of the tokens to the unauthorized user
        uint256 tokensToSend = initialBalance / 2;
        vm.prank(userA);
        aToken.transfer(unauthorizedUser, tokensToSend);
        // create send param
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(300000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(unauthorizedUser),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);
        vm.prank(unauthorizedUser);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.AccountUnauthorized.selector, unauthorizedUser));
        aOFTAdapter.send{ value: fee.nativeFee }(sendParam, fee, userA);
    }

    function test_RevertIf_SendWhilePaused() public {
        uint256 tokensToSend = 580 * 10 ** aTokenDecimals;
        vm.prank(pauser);
        aOFTAdapter.pause();

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(300000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(userA),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);
        vm.startPrank(userA);
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        aOFTAdapter.send(sendParam, fee, userA);
        vm.stopPrank();
    }

    // NOTE: This should be part of the Documentation, noting that such small amounts are not supported.
    function test_RevertWhen_SendDustAmount() public {
        uint256 initialBalance = aToken.balanceOf(userA);
        uint256 tokensThatCanBeSent = 1 * 10 ** (aTokenDecimals); // 1 token with decimals
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
        assertTrue(initialBalance > tokensToSend); // test validity check

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(300000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(userA),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );

        vm.expectRevert(
            abi.encodeWithSelector(IOFT.SlippageExceeded.selector, tokensThatCanBeSent, tokensToSend) // SlippageExceeded(amountReceivedLD, _minAmountLD);
        );
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);
        // NOTE: SlippageExceeded is experienced on both quoteSend and send
        fee = MessagingFee({
            nativeFee: 1 ether, // NOTE: This is not the actual fee. This is just a placeholder,
            //       as the above assignment is expected to revert
            lzTokenFee: 0
        });

        vm.startPrank(userA);
        aToken.approve(address(aOFTAdapter), tokensToSend);

        vm.expectRevert(
            abi.encodeWithSelector(IOFT.SlippageExceeded.selector, tokensThatCanBeSent, tokensToSend) // SlippageExceeded(amountReceivedLD, _minAmountLD);
        );
        aOFTAdapter.send(sendParam, fee, userA);
        vm.stopPrank();
    }

    function test_RevertWhen_SendInsufficientBalance() public {
        uint256 initialBalance = aToken.balanceOf(userA);
        uint256 tokensToSend = initialBalance * 2;
        assertTrue(initialBalance < tokensToSend); // test validity check

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(300000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(userA),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);
        // couple more initial assertions
        assertEq(aToken.balanceOf(userA), initialBalance);
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0);
        assertEq(bToken.balanceOf(userA), 0);

        vm.startPrank(userA);
        aToken.approve(address(aOFTAdapter), tokensToSend);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                address(userA),
                initialBalance,
                tokensToSend
            )
        );
        aOFTAdapter.send(sendParam, fee, userA);
        vm.stopPrank();

        assertEq(aToken.balanceOf(userA), initialBalance);
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0); // no tokens sent
        assertEq(bToken.balanceOf(userA), 0); // no tokens received
    }

    function _createPermitSignature(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 permitHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner, spender, value, aToken.nonces(owner), deadline)
        );
        bytes32 permit712Digest = keccak256(abi.encodePacked("\x19\x01", aToken.DOMAIN_SEPARATOR(), permitHash));
        return vm.sign(userAPrivateKey, permit712Digest);
    }

    function _createAuthorizationSignature(
        IWusdOFTAdapter.OFTSendAuthorization memory authorization
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
        ); // We hash the SendParam struct first
        bytes32 sendAuthorizationHash = keccak256(
            abi.encode(
                aOFTAdapter.SEND_AUTHORIZATION_TYPEHASH(),
                authorization.owner,
                authorization.spender,
                authorization.value,
                authorization.permitNonce,
                authorization.deadline,
                sendParamsStructHash,
                authorization.nonce
            )
        );
        bytes32 authorization712Digest = keccak256(
            abi.encodePacked("\x19\x01", aOFTAdapter.DOMAIN_SEPARATOR(), sendAuthorizationHash)
        );
        return vm.sign(userAPrivateKey, authorization712Digest);
    }

    function test_sendTokensOnBehalfOfUserA() public {
        uint256 initialBalance = aToken.balanceOf(userA);
        uint256 tokensToSend = 580 * 10 ** aTokenDecimals;
        uint256 decimalConversionRate = 10 ** (aTokenDecimals - bTokenDecimals);
        uint256 tokensToReceive = tokensToSend / decimalConversionRate;
        uint256 deadline = block.timestamp + 60 * 5; // 5 minutes

        // Create SendParam
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(300000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(userA),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );

        // Create Authorization
        IWusdOFTAdapter.OFTSendAuthorization memory authorization = IWusdOFTAdapter.OFTSendAuthorization({
            owner: userA,
            spender: address(aOFTAdapter),
            value: tokensToSend,
            permitNonce: aToken.nonces(userA),
            deadline: deadline,
            sendParams: sendParam,
            nonce: aOFTAdapter.nonces(userA)
        });

        // Get signatures
        (uint8 permitV, bytes32 permitR, bytes32 permitS) = _createPermitSignature(
            userA,
            address(aOFTAdapter),
            tokensToSend,
            deadline
        );

        (uint8 v, bytes32 r, bytes32 s) = _createAuthorizationSignature(authorization);

        // Sponsor should quote send messaging fee
        vm.prank(userB);
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);

        // Initial assertions
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0);
        assertEq(bToken.balanceOf(address(bOFTAdapter)), 0);
        assertEq(aToken.balanceOf(userA), initialBalance);
        assertEq(bToken.balanceOf(userA), 0);
        assertEq(aToken.balanceOf(userB), 0);
        assertEq(bToken.balanceOf(userB), 0);

        // Execute sendWithAuthorization from a different address (e.g., userB)
        vm.prank(userB); // userB is the sponsor. we don't have an access registry on the OFT Adapter for this test
        aOFTAdapter.sendWithAuthorization{ value: fee.nativeFee }(
            authorization,
            permitV,
            permitR,
            permitS,
            v,
            r,
            s,
            fee,
            userB
        );
        verifyPackets(bEid, addressToBytes32(address(bOFTAdapter)));

        // Final assertions
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0); // tokens burned on source chain
        assertEq(bToken.balanceOf(address(bOFTAdapter)), 0); // tokens minted on destination chain and sent to userA
        assertEq(aToken.balanceOf(userA), initialBalance - tokensToSend);
        assertEq(bToken.balanceOf(userA), tokensToReceive);
        assertEq(aToken.balanceOf(userB), 0);
        assertEq(bToken.balanceOf(userB), 0);
        // some control fields
        assertEq(aOFTAdapter.nonces(userA), 1);
        assertEq(aOFTAdapter.nonces(userB), 0);
    }

    function test_RevertWhen_sendWithAuthorizationCallerNotInAllowlist() public {
        uint256 initialBalance = aToken.balanceOf(userA);
        uint256 tokensToSend = 580 * 10 ** aTokenDecimals;
        uint256 deadline = block.timestamp + 60 * 5; // 5 minutes

        // Create SendParam
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(300000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(userA),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        // Create Authorization
        IWusdOFTAdapter.OFTSendAuthorization memory authorization = IWusdOFTAdapter.OFTSendAuthorization({
            owner: userA,
            spender: address(aOFTAdapter),
            value: tokensToSend,
            permitNonce: aToken.nonces(userA),
            deadline: deadline,
            sendParams: sendParam,
            nonce: aOFTAdapter.nonces(userA)
        });

        // Get signatures
        (uint8 permitV, bytes32 permitR, bytes32 permitS) = _createPermitSignature(
            userA,
            address(aOFTAdapter),
            tokensToSend,
            deadline
        );

        (uint8 v, bytes32 r, bytes32 s) = _createAuthorizationSignature(authorization);

        // Sponsor should quote send messaging fee
        vm.prank(userB);
        MessagingFee memory fee = aOFTAdapter.quoteSend(sendParam, false);

        // Initial assertions
        assertEq(aToken.balanceOf(address(aOFTAdapter)), 0);
        assertEq(bToken.balanceOf(address(bOFTAdapter)), 0);
        assertEq(aToken.balanceOf(userA), initialBalance);
        assertEq(bToken.balanceOf(userA), 0);
        assertEq(aToken.balanceOf(userB), 0);
        assertEq(bToken.balanceOf(userB), 0);

        // set adapter access registry on OFT Adapter A
        vm.prank(contractAdmin);
        aOFTAdapter.accessRegistryUpdate(address(accessRegistryOAppA));

        // Execute sendWithAuthorization from userB (operator). It should fail because userB is not in the allowlist
        vm.startPrank(userB); // userB is the sponsor
        vm.expectRevert(abi.encodeWithSelector(LibErrors.AccountUnauthorized.selector, userB));
        aOFTAdapter.sendWithAuthorization{ value: fee.nativeFee }(
            authorization,
            permitV,
            permitR,
            permitS,
            v,
            r,
            s,
            fee,
            userB
        );
        vm.stopPrank();
    }
}
