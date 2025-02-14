// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { LibRoles } from "../../contracts/library/LibRoles.sol";
import "../../contracts/WusdOFTAdapter.sol";
import "../../test/mocks/ERC20Mock.sol";

contract WusdOFTAdapterRoleBasedOwnableTest is TestHelperOz5 {
    WusdOFTAdapter public adapter;
    ERC20Mock public token;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    address public defaultAdmin = makeAddr("defaultAdmin");
    address public admin = makeAddr("admin");
    address public placeholderAdmin = makeAddr("placeholderAdmin");
    address public user = makeAddr("user");

    function setUp() public virtual override {
        // Deploy mock ERC20F token
        token = new ERC20Mock("Token", "TOKEN", 18);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Deploy WusdOFTAdapter with necessary parameters
        vm.startPrank(defaultAdmin);
        adapter = new WusdOFTAdapter(
            address(token),             // token address
            address(endpoints[aEid]),   // mock LZ endpoint
            defaultAdmin,               // default admin
            admin                       // delegate (gets CONTRACT_ADMIN_ROLE)
        );
        vm.stopPrank();
    }

    function test_InitialRoles() public view {
        // Check DEFAULT_ADMIN_ROLE
        assertTrue(adapter.hasRole(LibRoles.DEFAULT_ADMIN_ROLE, defaultAdmin));
        assertFalse(adapter.hasRole(LibRoles.DEFAULT_ADMIN_ROLE, admin));
        // Check CONTRACT_ADMIN_ROLE
        assertTrue(adapter.hasRole(LibRoles.CONTRACT_ADMIN_ROLE, admin));
        assertFalse(adapter.hasRole(LibRoles.CONTRACT_ADMIN_ROLE, defaultAdmin));
        // Verify other roles are not assigned
        assertFalse(adapter.hasRole(LibRoles.PAUSER_ROLE, defaultAdmin));
        assertFalse(adapter.hasRole(LibRoles.SALVAGE_ROLE, defaultAdmin));
        assertFalse(adapter.hasRole(LibRoles.EMBARGO_ROLE, defaultAdmin));
    }

    function test_DefaultAdminCanGrantRoles() public {
        vm.startPrank(defaultAdmin);

        vm.expectEmit(true, true, true, true);
        emit IAccessControl.RoleGranted(LibRoles.PAUSER_ROLE, placeholderAdmin, defaultAdmin);
        adapter.grantRole(LibRoles.PAUSER_ROLE, placeholderAdmin);
        assertTrue(adapter.hasRole(LibRoles.PAUSER_ROLE, placeholderAdmin));

        vm.expectEmit(true, true, true, true);
        emit IAccessControl.RoleGranted(LibRoles.SALVAGE_ROLE, placeholderAdmin, defaultAdmin);
        adapter.grantRole(LibRoles.SALVAGE_ROLE, placeholderAdmin);
        assertTrue(adapter.hasRole(LibRoles.SALVAGE_ROLE, placeholderAdmin));

        vm.expectEmit(true, true, true, true);
        emit IAccessControl.RoleGranted(LibRoles.EMBARGO_ROLE, placeholderAdmin, defaultAdmin);
        adapter.grantRole(LibRoles.EMBARGO_ROLE, placeholderAdmin);
        assertTrue(adapter.hasRole(LibRoles.EMBARGO_ROLE, placeholderAdmin));

        vm.stopPrank();
    }

    function test_DefaultAdminCanRevokeRoles() public {
        // First grant roles
        vm.startPrank(defaultAdmin);
        adapter.grantRole(LibRoles.PAUSER_ROLE, placeholderAdmin);
        adapter.grantRole(LibRoles.SALVAGE_ROLE, placeholderAdmin);

        // Then revoke them
        vm.expectEmit(true, true, true, true);
        emit IAccessControl.RoleRevoked(LibRoles.PAUSER_ROLE, placeholderAdmin, defaultAdmin);
        adapter.revokeRole(LibRoles.PAUSER_ROLE, placeholderAdmin);
        vm.expectEmit(true, true, true, true);
        emit IAccessControl.RoleRevoked(LibRoles.SALVAGE_ROLE, placeholderAdmin, defaultAdmin);
        adapter.revokeRole(LibRoles.SALVAGE_ROLE, placeholderAdmin);

        assertFalse(adapter.hasRole(LibRoles.PAUSER_ROLE, placeholderAdmin));
        assertFalse(adapter.hasRole(LibRoles.SALVAGE_ROLE, placeholderAdmin));
        vm.stopPrank();
    }

    function test_RoleAdminIsDefaultAdminRole() public view {
        // Verify that DEFAULT_ADMIN_ROLE is the admin role for all other roles
        assertEq(adapter.getRoleAdmin(LibRoles.PAUSER_ROLE), LibRoles.DEFAULT_ADMIN_ROLE);
        assertEq(adapter.getRoleAdmin(LibRoles.CONTRACT_ADMIN_ROLE), LibRoles.DEFAULT_ADMIN_ROLE);
        assertEq(adapter.getRoleAdmin(LibRoles.SALVAGE_ROLE), LibRoles.DEFAULT_ADMIN_ROLE);
        assertEq(adapter.getRoleAdmin(LibRoles.EMBARGO_ROLE), LibRoles.DEFAULT_ADMIN_ROLE);
    }

    function test_NonAdminCannotGrantRoles() public {
        vm.startPrank(user);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                LibRoles.DEFAULT_ADMIN_ROLE
            )
        );
        adapter.grantRole(LibRoles.PAUSER_ROLE, placeholderAdmin);

        vm.stopPrank();
    }

    function test_NonAdminCannotRevokeRoles() public {
        vm.startPrank(user);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                LibRoles.DEFAULT_ADMIN_ROLE
            )
        );
        adapter.revokeRole(LibRoles.PAUSER_ROLE, placeholderAdmin);

        vm.stopPrank();
    }

    function test_RoleBasedOwnershipChecks() public {
        // Test that CONTRACT_ADMIN_ROLE can perform owner-like actions
        vm.prank(admin);
        adapter.setDelegate(placeholderAdmin); // This is an owner-only function from OAppCore

        // Test that non-CONTRACT_ADMIN_ROLE cannot perform owner-like actions
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                LibRoles.CONTRACT_ADMIN_ROLE
            )
        );
        adapter.setDelegate(user);
        vm.stopPrank();
    }

    function test_RenounceRole() public {
        // Grant a role to user
        vm.prank(defaultAdmin);
        adapter.grantRole(LibRoles.PAUSER_ROLE, user);
        assertTrue(adapter.hasRole(LibRoles.PAUSER_ROLE, user));

        // User can renounce their own role
        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit IAccessControl.RoleRevoked(LibRoles.PAUSER_ROLE, user, user);
        adapter.renounceRole(LibRoles.PAUSER_ROLE, user);
        assertFalse(adapter.hasRole(LibRoles.PAUSER_ROLE, user));
    }

    function test_RevertWhen_RenounceOtherAccountRole() public {
        // Grant a role to user
        vm.prank(defaultAdmin);
        adapter.grantRole(LibRoles.PAUSER_ROLE, user);

        // Another account cannot renounce user's role
        vm.prank(placeholderAdmin);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlBadConfirmation.selector));
        adapter.renounceRole(LibRoles.PAUSER_ROLE, user);
    }

    function test_OwnershipIsRenounced() public view {
        // Check that ownership was properly renounced in constructor
        assertEq(adapter.owner(), address(0));
    }

    function test_RevertWhen_DefaultAdminRevokesOwnRole() public {
        vm.prank(defaultAdmin);
        vm.expectRevert(LibErrors.DefaultAdminError.selector);
        adapter.revokeRole(LibRoles.DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    function test_DefaultAdminCanRevokeOtherDefaultAdmin() public {
        // First grant DEFAULT_ADMIN_ROLE to another account
        vm.prank(defaultAdmin);
        adapter.grantRole(LibRoles.DEFAULT_ADMIN_ROLE, placeholderAdmin);

        // Then revoke it
        vm.prank(defaultAdmin);
        adapter.revokeRole(LibRoles.DEFAULT_ADMIN_ROLE, placeholderAdmin);

        assertFalse(adapter.hasRole(LibRoles.DEFAULT_ADMIN_ROLE, placeholderAdmin));
    }

    function test_RevertWhen_RenounceDefaultAdminRole() public {
        vm.prank(defaultAdmin);
        vm.expectRevert(LibErrors.DefaultAdminError.selector);
        adapter.renounceRole(LibRoles.DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    function test_RevertWhen_PausedRoleManagement() public {
        // First grant PAUSER_ROLE to be able to pause
        vm.prank(defaultAdmin);
        adapter.grantRole(LibRoles.PAUSER_ROLE, defaultAdmin);

        // Pause the contract
        vm.prank(defaultAdmin);
        adapter.pause();

        // Try to grant a role while paused
        vm.prank(defaultAdmin);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        adapter.grantRole(LibRoles.SALVAGE_ROLE, user);

        // Try to revoke a role while paused
        vm.prank(defaultAdmin);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        adapter.revokeRole(LibRoles.PAUSER_ROLE, defaultAdmin);

        // Try to renounce a role while paused
        vm.prank(user);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        adapter.renounceRole(LibRoles.PAUSER_ROLE, user);
    }

    function test_MultipleDefaultAdmins() public {
        // Grant DEFAULT_ADMIN_ROLE to another account
        vm.prank(defaultAdmin);
        adapter.grantRole(LibRoles.DEFAULT_ADMIN_ROLE, placeholderAdmin);
        // Original admin should still maintain their role
        assertTrue(adapter.hasRole(LibRoles.DEFAULT_ADMIN_ROLE, defaultAdmin));

        // Verify both accounts can perform admin actions
        vm.prank(defaultAdmin);
        adapter.grantRole(LibRoles.PAUSER_ROLE, user);

        vm.prank(placeholderAdmin);
        adapter.grantRole(LibRoles.SALVAGE_ROLE, user);

        assertTrue(adapter.hasRole(LibRoles.PAUSER_ROLE, user));
        assertTrue(adapter.hasRole(LibRoles.SALVAGE_ROLE, user));
    }

    function test_DefaultAdminRoleManagement() public {
        // Grant DEFAULT_ADMIN_ROLE to new admin
        vm.prank(defaultAdmin);
        adapter.grantRole(LibRoles.DEFAULT_ADMIN_ROLE, placeholderAdmin);
        assertTrue(adapter.hasRole(LibRoles.DEFAULT_ADMIN_ROLE, placeholderAdmin));

        // New admin should be able to grant roles
        vm.prank(placeholderAdmin);
        adapter.grantRole(LibRoles.PAUSER_ROLE, user);
        assertTrue(adapter.hasRole(LibRoles.PAUSER_ROLE, user));
    }

    function test_RoleManagementWhenUnpaused() public {
        // First pause the contract
        vm.prank(defaultAdmin);
        adapter.grantRole(LibRoles.PAUSER_ROLE, defaultAdmin);
        vm.prank(defaultAdmin);
        adapter.pause();

        // Then unpause
        vm.prank(defaultAdmin);
        adapter.unpause();

        // Verify role management works after unpausing
        vm.prank(defaultAdmin);
        adapter.grantRole(LibRoles.SALVAGE_ROLE, user);
        assertTrue(adapter.hasRole(LibRoles.SALVAGE_ROLE, user));

        vm.prank(defaultAdmin);
        adapter.revokeRole(LibRoles.SALVAGE_ROLE, user);
        assertFalse(adapter.hasRole(LibRoles.SALVAGE_ROLE, user));
    }
}
