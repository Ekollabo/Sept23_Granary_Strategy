// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IDataProvider} from "./interfaces/IDataProvider.sol";
import {IAaveIncentives} from "./interfaces/IAaveIncentives.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {IReaperVault} from "./interfaces/IReaperVault.sol";

contract Strategy {
    address payable public vault;

    // tokens used
    address public want; // WBTC
    address public loanToken; //DAI
    address public aToken; //Aave token
    //    contracts used Aave
    address public lendingPool; //Aave lending pool
    address public dataProvider; //Aave data provider
    address public incentiveController; //Aave incentive controller
    address public priceOracle; //Aave price oracle
    //Reaper contracts
    address public reaperVault; //DAI vault

    //Contants
    uint256 public constant PERCENT_DIVISOR = 10000;
    uint256 public constant LoanPercent = 500;

    constructor(
        address _vault,
        address _want,
        address _loanToken,
        address _aToken,
        address _lendingPool,
        address _dataProvider,
        address _incentiveController,
        address _priceOracle,
        address _reaperVault
    ) {
        vault = payable(_vault);
        want = _want;
        loanToken = _loanToken;
        aToken = _aToken;
        lendingPool = _lendingPool;
        dataProvider = _dataProvider;
        incentiveController = _incentiveController;
        priceOracle = _priceOracle;
        reaperVault = _reaperVault;

        (aToken,,) = IDataProvider(dataProvider).getReserveTokensAddresses(want);
    }

    function deposit() external {
        require(msg.sender == vault, "!vault");
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        if (wantBal > 0) {
            // deposit to Aave
            IERC20(want).approve(lendingPool, wantBal);
            ILendingPool(lendingPool).deposit(want, wantBal, address(this), 0); //get some aTokens
            //get price of want
            uint256 wantPrice = IPriceOracle(priceOracle).getAssetPrice(want);
            uint256 totalWantValue = wantBal * wantPrice;
            uint256 borrowAmount = totalWantValue * LoanPercent / PERCENT_DIVISOR; // maitaining 200% collateral
            //Borrow
            ILendingPool(lendingPool).borrow(loanToken, borrowAmount, 2, 0, address(this));
            //Deposit to reaper vault
            IERC20(loanToken).approve(reaperVault, borrowAmount); //Approve reaper vault to spend DAI.
            IReaperVault(reaperVault).deposit(borrowAmount, address(this));
            //We will get some shares
        }
    }

    /**
     * @dev Withdraws funds and sends them back to the vault.
     */

    function withdraw(uint256 _amount) external {
        require(msg.sender == vault, "!vault");
        uint256 bal = IERC20(want).balanceOf(address(this));
        if (bal < _amount) {
            //Withdraw from reaper vault
            IReaperVault(reaperVault).withdraw(_amount - bal, address(this), address(this));
            //Repay loan
            ILendingPool(lendingPool).repay(loanToken, _amount - bal, 2, address(this));
            //Withdraw from Aave
            ILendingPool(lendingPool).withdraw(want, _amount - bal, address(this));
        }

        IERC20(want).transfer(vault, _amount);
    }

    /* ----------------------------- VIEW FUNCTIONS ----------------------------- */
    // return supply and borrow balance
    function userReserves() public view returns (uint256, uint256) {
        (uint256 supplyBal,, uint256 borrowBal,,,,,,) =
            IDataProvider(dataProvider).getUserReserveData(want, address(this));
        // I think we also need to take borrow fee into account
        return (supplyBal, borrowBal);
    }

    function balanceOfPool() public view returns (uint256) {
        (uint256 supplyBal, uint256 borrowBal) = userReserves();
        return supplyBal - borrowBal;
    }

    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function earnedYieldInWant() public view returns (uint256) {
        uint256 assets = IReaperVault(reaperVault).convertToAsset(reaperVault.balanceOf(address(this)));
        uint256 wantPrice = IPriceOracle(priceOracle).getAssetPrice(want);
        // uint256 wantDecimals = IERC20(want).decimals();
        // uint256 loanTokenDecimals = IERC20(loanToken).decimals();
        uint256 wantAmount = assets / wantPrice; //@audit consider wbtc have 8 decimals
        return balanceOfPool() - wantAmount; // return earned yield in WBTC
    }

    function balanceOf() public view returns (uint256) {
        uint256 bal = balanceOfWant() + balanceOfPool() + earnedYieldInWBTC();
    }
}
