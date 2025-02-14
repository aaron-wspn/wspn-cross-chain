// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../contracts/WusdOFTAdapter.sol";
import { ERC20Mock, IERC20Errors } from "../../test/mocks/ERC20Mock.sol";
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { LibErrors } from "../../contracts/library/LibErrors.sol";
import { LibRoles } from "../../contracts/library/LibRoles.sol";

contract WusdOFTAdapterSalvageCapableTest is TestHelperOz5 {
    WusdOFTAdapter public adapter;
    ERC20Mock public innerToken;
    ERC20Mock public randomToken;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    address public defaultAdmin = makeAddr("defaultAdmin");
    address public admin = makeAddr("admin");
    address public salvager = makeAddr("salvager");
    address public user = makeAddr("user");

    event TokenSalvaged(address indexed caller, address indexed token, uint256 indexed amount);
    event GasTokenSalvaged(address indexed caller, uint256 indexed amount);

    function setUp() public virtual override {
        // Deploy mock tokens
        innerToken = new ERC20Mock("Inner Token", "INNER", 18);
        randomToken = new ERC20Mock("Random Token", "RANDOM", 18);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Deploy WusdOFTAdapter with necessary parameters
        vm.startPrank(defaultAdmin);
        adapter = new WusdOFTAdapter(
            address(innerToken),        // token address
            address(endpoints[aEid]),   // mock LZ endpoint
            defaultAdmin,               // default admin
            admin                       // delegate (gets CONTRACT_ADMIN_ROLE)
        );

        // Setup roles
        adapter.grantRole(LibRoles.SALVAGE_ROLE, salvager);
        vm.stopPrank();
    }

    function test_RevertWhen_NonSalvagerSalvagesERC20() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                LibRoles.SALVAGE_ROLE
            )
        );
        adapter.salvageERC20(IERC20(address(randomToken)), 100);
        vm.stopPrank();
    }

    function test_RevertWhen_NonSalvagerSalvagesGas() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                LibRoles.SALVAGE_ROLE
            )
        );
        adapter.salvageGas(100);
        vm.stopPrank();
    }

    function test_RevertWhen_SalvageZeroERC20() public {
        vm.startPrank(salvager);
        vm.expectRevert(LibErrors.ZeroAmount.selector);
        adapter.salvageERC20(IERC20(address(randomToken)), 0);
        vm.stopPrank();
    }

    function test_RevertWhen_SalvageZeroGas() public {
        vm.startPrank(salvager);
        vm.expectRevert(LibErrors.ZeroAmount.selector);
        adapter.salvageGas(0);
        vm.stopPrank();
    }

    function test_RevertWhen_SalvageInnerToken() public {
        vm.startPrank(salvager);
        vm.expectRevert(LibErrors.UnauthorizedTokenManagement.selector);
        adapter.salvageERC20(IERC20(address(innerToken)), 100);
        vm.stopPrank();
    }

    function test_SalvageERC20() public {
        uint256 amount = 100;
        // Setup: Send some tokens to the adapter
        randomToken.mint(address(adapter), amount);
        assertEq(randomToken.balanceOf(address(adapter)), amount);
        assertEq(randomToken.balanceOf(salvager), 0);

        vm.startPrank(salvager);

        vm.expectEmit(true, true, true, true);
        emit TokenSalvaged(salvager, address(randomToken), amount);

        adapter.salvageERC20(IERC20(address(randomToken)), amount);

        // Verify balances after salvage
        assertEq(randomToken.balanceOf(address(adapter)), 0);
        assertEq(randomToken.balanceOf(salvager), amount);

        vm.stopPrank();
    }

    function test_RevertWhen_SalvageERC20InsufficientBalance() public {
        uint256 amount = 100;
        uint256 amountMoreThanBalance = amount + 1;
        // Setup: Send some tokens to the adapter
        randomToken.mint(address(adapter), amount);
        assertEq(randomToken.balanceOf(address(adapter)), amount);
        assertEq(randomToken.balanceOf(salvager), 0);

        vm.startPrank(salvager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                address(adapter),
                randomToken.balanceOf(address(adapter)),
                amountMoreThanBalance
            )
        );
        adapter.salvageERC20(IERC20(address(randomToken)), amountMoreThanBalance);
        vm.stopPrank();
    }

    function test_SalvageGas() public {
        uint256 amount = 1 ether;
        // Setup: Send some ETH to the adapter
        vm.deal(address(adapter), amount);
        assertEq(address(adapter).balance, amount);
        assertEq(address(salvager).balance, 0);

        vm.startPrank(salvager);

        vm.expectEmit(true, true, true, true);
        emit GasTokenSalvaged(salvager, amount);

        adapter.salvageGas(amount);

        // Verify balances after salvage
        assertEq(address(adapter).balance, 0);
        assertEq(address(salvager).balance, amount);

        vm.stopPrank();
    }

    function test_RevertWhen_SalvageGasInsufficientBalance() public {
        uint256 amount = 1 ether;
        // Setup: Send less ETH than we'll try to salvage
        vm.deal(address(adapter), amount - 0.5 ether);

        vm.startPrank(salvager);
        vm.expectRevert(LibErrors.SalvageGasFailed.selector);
        adapter.salvageGas(amount);
        vm.stopPrank();
    }

    function test_RevertWhen_PausedSalvageERC20() public {
        // Setup: Grant PAUSER_ROLE and pause the contract
        vm.startPrank(defaultAdmin);
        adapter.grantRole(LibRoles.PAUSER_ROLE, defaultAdmin);
        adapter.pause();
        vm.stopPrank();

        vm.startPrank(salvager);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        adapter.salvageERC20(IERC20(address(randomToken)), 100);
        vm.stopPrank();
    }

    function test_RevertWhen_PausedSalvageGas() public {
        // Setup: Grant PAUSER_ROLE and pause the contract
        vm.startPrank(defaultAdmin);
        adapter.grantRole(LibRoles.PAUSER_ROLE, defaultAdmin);
        adapter.pause();
        vm.stopPrank();

        vm.startPrank(salvager);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        adapter.salvageGas(100);
        vm.stopPrank();
    }

    function test_SalvageAfterUnpause() public {
        uint256 amount = 100;
        // Setup: Send tokens and pause
        randomToken.mint(address(adapter), amount);
        vm.startPrank(defaultAdmin);
        adapter.grantRole(LibRoles.PAUSER_ROLE, defaultAdmin);
        adapter.pause();

        // Unpause
        adapter.unpause();
        vm.stopPrank();

        // Should be able to salvage after unpause
        vm.startPrank(salvager);
        adapter.salvageERC20(IERC20(address(randomToken)), amount);
        assertEq(randomToken.balanceOf(salvager), amount);
        vm.stopPrank();
    }

    function test_PartialSalvageERC20() public {
        uint256 totalAmount = 100;
        uint256 salvageAmount = 60;
        // Setup: Send some tokens to the adapter
        randomToken.mint(address(adapter), totalAmount);

        vm.startPrank(salvager);
        adapter.salvageERC20(IERC20(address(randomToken)), salvageAmount);

        // Verify partial salvage
        assertEq(randomToken.balanceOf(address(adapter)), totalAmount - salvageAmount);
        assertEq(randomToken.balanceOf(salvager), salvageAmount);
        vm.stopPrank();
    }

    function test_PartialSalvageGas() public {
        uint256 totalAmount = 1 ether;
        uint256 salvageAmount = 0.6 ether;
        // Setup: Send some ETH to the adapter
        vm.deal(address(adapter), totalAmount);

        vm.startPrank(salvager);
        adapter.salvageGas(salvageAmount);

        // Verify partial salvage
        assertEq(address(adapter).balance, totalAmount - salvageAmount);
        assertEq(address(salvager).balance, salvageAmount);
        vm.stopPrank();
    }
}
