// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {ILendingPool} from "../../src/interfaces/ILendingPool.sol";
import {IDataProvider} from "../../src/interfaces/IDataProvider.sol";
import {IAaveIncentives} from "../../src/interfaces/IAaveIncentives.sol";
import {IPriceOracle} from "../../src/interfaces/IPriceOracle.sol";

contract ForkHelper {
    // tokens used
    IERC20 public want = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599); // WBTC
    IERC20 public loanToken = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F); //DAI
    //    contracts used Aave
    ILendingPool public lendingPool = ILendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD); //Aave lending pool
    IDataProvider public dataProvider = IDataProvider(0x69FA688f1Dc47d4B5d8029D5a35FB7a548310654); //Aave data provider
    IAaveIncentives public incentiveController = IAaveIncentives(0x929EC64c34a17401F460460D4B9390518E5B473e); //Aave incentive controller
    IPriceOracle public priceOracle = IPriceOracle(0xD81eb3728a631871a7eBBaD631b5f424909f0c77); //Aave price oracle returns 8dec
    //Reaper contracts
    address public reaperVault = 0xc0F5DA4FB484CE6d8a6832819299F7cD0D15726E; //DAI vault
}
