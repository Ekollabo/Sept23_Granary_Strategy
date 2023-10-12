// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {ILendingPool} from "../src/interfaces/ILendingPool.sol";
import {IDataProvider} from "../src/interfaces/IDataProvider.sol";
import {IAaveIncentives} from "../src/interfaces/IAaveIncentives.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";
import {MaxiVault} from "../src/MaxiVault.sol";
import {Strategy} from "../src/Strategy.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

interface IERC20Extented is IERC20 {
    function decimals() external view returns (uint8);
}

contract ForkHelper is Test {
    /* ------------------------------- tokens used ----------------j-------------- */
    address public want = 0x68f180fcCe6836688e9084f035309E29Bf0A2095; // WBTC
    address public loanToken = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; //DAI
    /* ------------------------    contracts used Aave ----------------------- */
    address public lendingPool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD; //Aave lending pool
    address public dataProvider = 0x69FA688f1Dc47d4B5d8029D5a35FB7a548310654; //Aave data provider
    address public incentiveController = 0x929EC64c34a17401F460460D4B9390518E5B473e; //Aave incentive controller
    address public priceOracle = 0xD81eb3728a631871a7eBBaD631b5f424909f0c77; //Aave price oracle returns 8dec

    /* --------------------------- Reaper contracts --------------------------- */
    address public reaperVault = 0xc0F5DA4FB484CE6d8a6832819299F7cD0D15726E; //DAI vault
    /* ---------------------------------- USERS --------------------------------- */

    /* ---------------------------- CUSTOM CONTRACTS ---------------------------- */

    // setup
    MaxiVault public maxiVault;
    Strategy public strategy;

    function setUp() public virtual {
        string memory rpc = vm.envString("RPC_URL");
        uint256 optimismFork = vm.createSelectFork(rpc);
        assertEq(vm.activeFork(), optimismFork);
        // fund user
        // deal(want, user1, 1000e8, true);
        // deal(want, user2, 1000e8, true);

        maxiVault = new MaxiVault(address(want), "MaxiVault WBTC", "mvWBTC", 0, 0);
        strategy = new Strategy(
            address(maxiVault),
            address(want),
            address(loanToken),
            address(lendingPool),
            address(dataProvider),
            address(incentiveController),
            address(priceOracle),
            address(reaperVault)
        );

        maxiVault.initialize(address(strategy));
    }
}
