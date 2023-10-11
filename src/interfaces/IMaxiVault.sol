// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

interface IMaxiVault {
    function strategy() external view returns (address);
    function depositFee() external view returns (uint256);
    function PERCENT_DIVISOR() external view returns (uint256);
    function tvlCap() external view returns (uint256);
    function initialized() external view returns (bool);
    function constructionTime() external view returns (uint256);
    function token() external view returns (IERC20);
    function cumulativeDeposits(address user) external view returns (uint256);
    function cumulativeWithdrawals(address user) external view returns (uint256);
    function balance() external view returns (uint256);
    function available() external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
    function depositAll() external;
    function deposit(uint256 amount) external;
    function earn() external;
    function withdrawAll() external;
    function withdraw(uint256 shares) external;
    function updateDepositFee(uint256 fee) external;
    function updateTvlCap(uint256 newTvlCap) external;
    function removeTvlCap() external;
    function incrementDeposits(uint256 amount) external returns (bool);
    function incrementWithdrawals(uint256 amount) external returns (bool);
    function inCaseTokensGetStuck(address token) external;
}
