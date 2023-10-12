// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {ILendingPool} from "../src/interfaces/ILendingPool.sol";
import {IDataProvider} from "../src/interfaces/IDataProvider.sol";
import {IAaveIncentives} from "../src/interfaces/IAaveIncentives.sol";
import {IReaperVault} from "../src/interfaces/IReaperVault.sol";
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
    IERC20Extented public want = IERC20Extented(0x68f180fcCe6836688e9084f035309E29Bf0A2095); // WBTC
    IERC20Extented public loanToken = IERC20Extented(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1); //DAI
    /* ------------------------    contracts used Aave ----------------------- */
    ILendingPool public lendingPool = ILendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD); //Aave lending pool
    IDataProvider public dataProvider = IDataProvider(0x69FA688f1Dc47d4B5d8029D5a35FB7a548310654); //Aave data provider
    IAaveIncentives public incentiveController = IAaveIncentives(0x929EC64c34a17401F460460D4B9390518E5B473e); //Aave incentive controller
    IPriceOracle public priceOracle = IPriceOracle(0xD81eb3728a631871a7eBBaD631b5f424909f0c77); //Aave price oracle returns 8dec

    /* --------------------------- Reaper contracts --------------------------- */
    IReaperVault public reaperVault = IReaperVault(0xc0F5DA4FB484CE6d8a6832819299F7cD0D15726E); //DAI vault
        /* ---------------------------------- USERS --------------------------------- */
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    /* ---------------------------- CUSTOM CONTRACTS ---------------------------- */

    // setup
    MaxiVault public maxiVault;
    Strategy public strategy;

    function setUp() public virtual {
        string memory rpc = vm.envString("RPC_URL");
        uint256 optimismFork = vm.createSelectFork(rpc, 110757864);
        assertEq(vm.activeFork(), optimismFork);

        maxiVault = new MaxiVault(address(want), "MaxiVault WBTC", "mvWBTC", 0, 1e6 * 1e18); //1m
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
