// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "openzeppelin/token/ERC20/ERC20.sol";

contract WBTC is ERC20 {
    constructor() ERC20("Wrapped BTC", "WBTC") {
        _mint(msg.sender, 1000000 * (10 ** decimals()));
    }
}
