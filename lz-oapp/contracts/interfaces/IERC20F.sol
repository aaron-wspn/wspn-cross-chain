// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20F {
    // Errors
    error AccessRegistryNotSet();
    error DefaultAdminError();
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidSpender(address spender);
    error InvalidAddress();
    error InvalidImplementation();
    error RecoveryOnActiveAccount(address account);
    error SalvageGasFailed();
    error ZeroAmount();

    // Events
    event AccessRegistryUpdated(
        address indexed caller,
        address indexed oldAccessRegistry,
        address indexed newAccessRegistry
    );
    event AdminChanged(address previousAdmin, address newAdmin);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event BeaconUpgraded(address indexed beacon);
    event ContractUriUpdated(address indexed caller, string oldUri, string newUri);
    event EIP712DomainChanged();
    event GasTokenSalvaged(address indexed caller, uint256 amount);
    event Initialized(uint8 version);
    event Paused(address account);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event TokenSalvaged(address indexed caller, address indexed token, uint256 amount);
    event TokensRecovered(address indexed caller, address indexed account, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Unpaused(address account);
    event Upgraded(address indexed implementation);

    // Functions
    function BURNER_ROLE() external view returns (bytes32);
    function CONTRACT_ADMIN_ROLE() external view returns (bytes32);
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function MINTER_ROLE() external view returns (bytes32);
    function PAUSER_ROLE() external view returns (bytes32);
    function RECOVERY_ROLE() external view returns (bytes32);
    function SALVAGE_ROLE() external view returns (bytes32);
    function UPGRADER_ROLE() external view returns (bytes32);
    function accessRegistry() external view returns (address);
    function accessRegistryUpdate(address _accessRegistry) external;
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function burn(uint256 amount) external;
    function contractUri() external view returns (string memory);
    function contractUriUpdate(string calldata _uri) external;
    function decimals() external view returns (uint8);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function initialize(
        string calldata _name,
        string calldata _symbol,
        address defaultAdmin,
        address minter,
        address pauser
    ) external;
    function mint(address to, uint256 amount) external;
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);
    function name() external view returns (string memory);
    function nonces(address owner) external view returns (uint256);
    function pause() external;
    function paused() external view returns (bool);
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function proxiableUUID() external view returns (bytes32);
    function recoverTokens(address account, uint256 amount) external;
    function renounceRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function salvageERC20(address token, uint256 amount) external;
    function salvageGas(uint256 amount) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function unpause() external;
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
    function version() external view returns (uint64);
}
