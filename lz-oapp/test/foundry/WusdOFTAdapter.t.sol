// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import { TestHelperOz5, EndpointV2 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

// OApp imports
import { IOAppOptionsType3, EnforcedOptionParam } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import { LibErrors } from "../../contracts/library/LibErrors.sol";
import { SendParam, MessagingFee } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import "../../contracts/interfaces/IERC20F.sol";
import { IWusdOFTAdapter } from "../../contracts/interfaces/IWusdOFTAdapter.sol";
import "../../contracts/WusdOFTAdapter.sol";
import "../mocks/ERC20Mock.sol";
import "../mocks/AccessRegistryMock.sol";

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
        vm.skip(true);
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

    function _createPermitSignature(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 permitHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            owner,
            spender,
            value,
            aToken.nonces(owner),
            deadline
        ));
        bytes32 permit712Digest = keccak256(abi.encodePacked(
            "\x19\x01",
            aToken.DOMAIN_SEPARATOR(),
            permitHash
        ));
        return vm.sign(userAPrivateKey, permit712Digest);
    }

    function _createAuthorizationSignature(
        IWusdOFTAdapter.OFTSendAuthorization memory authorization
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 sendParamsHash = keccak256(abi.encode(
            authorization.sendParams.dstEid,
            authorization.sendParams.to,
            authorization.sendParams.amountLD,
            authorization.sendParams.minAmountLD,
            keccak256(authorization.sendParams.extraOptions),
            keccak256(authorization.sendParams.composeMsg),
            keccak256(authorization.sendParams.oftCmd)
        )); // We hash the SendParam struct first
         bytes32 sendAuthorizationHash = keccak256(abi.encode(
            aOFTAdapter.SEND_AUTHORIZATION_TYPEHASH(),
            authorization.owner,
            authorization.spender,
            authorization.value,
            authorization.permitNonce,
            authorization.deadline,
            sendParamsHash,
            authorization.nonce
        ));
        bytes32 authorization712Digest = keccak256(abi.encodePacked(
            "\x19\x01",
            aOFTAdapter.DOMAIN_SEPARATOR(),
            sendAuthorizationHash
        ));
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
}
