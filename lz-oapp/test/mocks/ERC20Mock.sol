// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ERC20, IERC20Errors } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract ERC20Mock is ERC20, ERC20Permit {
    uint8 private immutable _decimals;

    constructor(
        string memory _name, 
        string memory _symbol,
        uint8 decimals_
    ) ERC20(_name, _symbol) ERC20Permit(_name) {
        _decimals = decimals_;
    }

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }

    function burn(uint256 _amount) public {
        _burn(msg.sender, _amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
