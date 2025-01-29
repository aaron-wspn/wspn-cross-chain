// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { LibErrors } from "../../contracts/library/LibErrors.sol";
import { LibRoles } from "../../contracts/library/LibRoles.sol";
import { SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import "../../contracts/WusdOFTAdapter.sol";
import "../mocks/ERC20Mock.sol";
import "../mocks/AccessRegistryMock.sol";

contract WusdOFTAdapterAccessRegistrySubscriptionCapableTest is TestHelperOz5 {
    WusdOFTAdapter public adapter;
    ERC20Mock public token;
    AccessRegistryMock public accessRegistry;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    address public defaultAdmin = makeAddr("defaultAdmin");
    address public admin = makeAddr("admin");
    address public user = makeAddr("user");
    address public unauthorizedUser = makeAddr("unauthorizedUser");

    event AccessRegistryUpdated(
        address indexed caller,
        address indexed oldAccessRegistry,
        address indexed newAccessRegistry
    );

    function setUp() public virtual override {
        // Deploy mock token
        token = new ERC20Mock("Token", "TOKEN", 18);
        // Deploy mock access registry
        accessRegistry = new AccessRegistryMock();

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
        adapter.grantRole(LibRoles.CONTRACT_ADMIN_ROLE, admin);
        vm.stopPrank();
    }

    function test_InitialState() public view {
        assertEq(address(adapter.accessRegistry()), address(0));
    }

    function test_ContractAdminCanUpdateAccessRegistry() public {
        vm.startPrank(admin);

        vm.expectEmit(true, true, true, true);
        emit AccessRegistryUpdated(admin, address(0), address(accessRegistry));

        adapter.accessRegistryUpdate(address(accessRegistry));
        assertEq(address(adapter.accessRegistry()), address(accessRegistry));

        vm.stopPrank();
    }

    function test_RevertWhen_NonAdminUpdatesAccessRegistry() public {
        vm.startPrank(unauthorizedUser);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorizedUser,
                LibRoles.CONTRACT_ADMIN_ROLE
            )
        );

        adapter.accessRegistryUpdate(address(accessRegistry));
        vm.stopPrank();
    }

    function test_NoUpdateWhenSameAddress() public {
        // First update to accessRegistry
        vm.startPrank(admin);
        adapter.accessRegistryUpdate(address(accessRegistry));
        assertEq(address(adapter.accessRegistry()), address(accessRegistry));

        // Record logs for the second update
        vm.recordLogs();
        adapter.accessRegistryUpdate(address(accessRegistry));
        // Verify no events were emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0);

        // Verify state remains unchanged
        assertEq(address(adapter.accessRegistry()), address(accessRegistry));

        vm.stopPrank();
    }

    function test_UpdateAccessRegistryToZeroAddress() public {
        // First set to non-zero address
        vm.startPrank(admin);
        adapter.accessRegistryUpdate(address(accessRegistry));
        assertEq(address(adapter.accessRegistry()), address(accessRegistry));

        // Then update to zero address
        vm.expectEmit(true, true, true, true);
        emit AccessRegistryUpdated(admin, address(accessRegistry), address(0));

        adapter.accessRegistryUpdate(address(0));
        assertEq(address(adapter.accessRegistry()), address(0));

        vm.stopPrank();
    }

    function test_RevertWhen_UpdateToInvalidAccessRegistryEOA() public {
        address invalidRegistry = address(0x999);

        vm.startPrank(admin);
        vm.expectRevert(LibErrors.InvalidImplementation.selector);
        adapter.accessRegistryUpdate(invalidRegistry);
        vm.stopPrank();
    }

    function test_RevertWhen_UpdateToInvalidAccessRegistryContract() public {
        // Create a fake contract address
        address invalidRegistry = makeAddr("invalidRegistry");

        // Get the bytecode of ERC20Mock - a valid contract that doesn't implement IAccessRegistry
        bytes memory invalidCode = type(ERC20Mock).creationCode;
        vm.etch(invalidRegistry, invalidCode);
        // Verify our setup - address should have code but not implement the interface
        assertTrue(invalidRegistry.code.length > 0, "Should have code");

        vm.startPrank(admin);
        vm.expectRevert(LibErrors.InvalidImplementation.selector);
        adapter.accessRegistryUpdate(invalidRegistry);
        vm.stopPrank();
    }

    function test_RevertWhen_PausedAccessRegistryUpdate() public {
        // Setup: Grant PAUSER_ROLE and pause the contract
        vm.startPrank(defaultAdmin);
        adapter.grantRole(LibRoles.PAUSER_ROLE, defaultAdmin);
        adapter.pause();
        vm.stopPrank();

        vm.startPrank(admin);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        adapter.accessRegistryUpdate(address(accessRegistry));
        vm.stopPrank();
    }

    // TODO: Migrate the tests below that use send() to the main test file. Try to use a valid send() call so that
    // the tests are more realistic.
    function test_NoAccessCheckWhenRegistryIsZero() public {
        // Verify registry is zero address
        assertEq(address(adapter.accessRegistry()), address(0));

        // Even with no explicit access, call should pass access check
        // (though it will fail due to missing parameters)
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(); // Expect revert due to missing parameters, not due to access
        adapter.send(SendParam(0, bytes32(0), 0, 0, "", "", ""), MessagingFee(0, 0), address(0));
        vm.stopPrank();
    }

    function test_AccessCheckWithRegistry() public {
        // Setup access registry
        vm.startPrank(admin);
        adapter.accessRegistryUpdate(address(accessRegistry));
        vm.stopPrank();

        // Grant access to user
        accessRegistry.setAccess(user, true);

        // Test access check (this will pass as the user has access)
        vm.prank(user);
        // The actual send would fail due to missing parameters, but the access check should pass
        vm.expectRevert(); // Expect revert due to missing parameters, not due to access
        adapter.send(SendParam(0, bytes32(0), 0, 0, "", "", ""), MessagingFee(0, 0), address(0));
    }

    function test_RevertWhen_UnauthorizedAccess() public {
        // Setup access registry
        vm.startPrank(admin);
        adapter.accessRegistryUpdate(address(accessRegistry));
        vm.stopPrank();

        // Setup mock response to deny access
        accessRegistry.setDefaultResponse(false);

        // Test access check (this should fail as the user doesn't have access)
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.AccountUnauthorized.selector, unauthorizedUser));
        adapter.send(SendParam(0, bytes32(0), 0, 0, "", "", ""), MessagingFee(0, 0), address(0));
        vm.stopPrank();
    }
}
