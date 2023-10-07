// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IDataProvider} from "./interfaces/IDataProvider.sol";
import {IAaveV3Incentives} from "./interfaces/IAaveIncentives.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IPriceOracleGetter} from "./interfaces/IPriceOracle.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";

contract Strategy is IStrategy {
    address payable public vault;

    // tokens used
    address public asset; // WBTC
    address public loanToken; //USDC
    address public aToken; //Aave token
    address public reaperVaultToken;
    //    contracts used Aave
    address public lendingPool; //Aave lending pool
    address public dataProvider; //Aave data provider
    address public incentiveController; //Aave incentive controller
    address public priceOracle; //Aave price oracle
    //Reaper contracts
    address public reaperVault; //USDC vault
}
