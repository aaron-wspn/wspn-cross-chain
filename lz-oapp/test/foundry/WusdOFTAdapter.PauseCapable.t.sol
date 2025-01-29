// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../../contracts/WusdOFTAdapter.sol";
import "../../test/mocks/ERC20Mock.sol";
// DevTools imports
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract WusdOFTAdapterPauseCapableTest is TestHelperOz5 {
    WusdOFTAdapter public adapter;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    address public defaultAdmin = makeAddr("defaultAdmin");
    address public admin = makeAddr("admin");
    address public pauser = makeAddr("pauser");
    address public user = makeAddr("user");

    event Paused(address account);
    event Unpaused(address account);

    function setUp() public virtual override {
        // Deploy mock ERC20F token
        ERC20Mock token = new ERC20Mock("Token", "TOKEN", 18);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Deploy WusdOFTAdapter with necessary parameters
        vm.startPrank(defaultAdmin);
        adapter = new WusdOFTAdapter(
            address(token), // token address
            address(endpoints[aEid]), // mock LZ endpoint
            defaultAdmin, // default admin
            admin // delegate (gets OAPP_ADMIN_ROLE)
        );
        // Setup roles
        adapter.grantRole(LibRoles.PAUSER_ROLE, pauser);
        vm.stopPrank();
    }

    function test_InitialState() public view {
        assertFalse(adapter.paused());
    }

    function test_PauserCanPause() public {
        vm.startPrank(pauser);

        vm.expectEmit(true, true, true, true);
        emit Paused(pauser);

        adapter.pause();
        assertTrue(adapter.paused());

        vm.stopPrank();
    }

    function test_PauserCanUnpause() public {
        // First pause
        vm.prank(pauser);
        adapter.pause();

        // Then unpause
        vm.startPrank(pauser);

        vm.expectEmit(true, true, true, true);
        emit Unpaused(pauser);

        adapter.unpause();
        assertFalse(adapter.paused());

        vm.stopPrank();
    }

    function test_RevertWhen_NonPauserPauses() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, LibRoles.PAUSER_ROLE)
        );
        adapter.pause();
    }

    function test_RevertWhen_NonPauserUnpauses() public {
        // First pause by authorized pauser
        vm.prank(pauser);
        adapter.pause();

        // Attempt to unpause by unauthorized user
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, LibRoles.PAUSER_ROLE)
        );
        adapter.unpause();
    }

    function test_RevertWhen_PausingWhenPaused() public {
        vm.startPrank(pauser);
        adapter.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        adapter.pause();
        vm.stopPrank();
    }

    function test_RevertWhen_UnpausingWhenNotPaused() public {
        vm.prank(pauser);
        vm.expectRevert(Pausable.ExpectedPause.selector);
        adapter.unpause();
    }

    function test_RevertIf_EmbargoRecoveryWhenPaused() public {
        // First pause the contract
        vm.prank(pauser);
        adapter.pause();

        // Try to recover embargo (should revert when paused)
        // NOTE: We are not testing the actual recovery of the embargo here, but the fact
        // that the function reverts when paused.
        // In fact, the function would otherwise still revert because the caller is not
        // an account with the EMBARGO_ROLE
        vm.expectRevert(Pausable.EnforcedPause.selector);
        adapter.recoverEmbargo(address(0x1), address(0x2));
    }
}
