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
    address public want; // WBTC
    address public loanToken; //DAI
    address public aToken; //Aave token
    address public reaperVault;
    //    contracts used Aave
    address public lendingPool; //Aave lending pool
    address public dataProvider; //Aave data provider
    address public incentiveController; //Aave incentive controller
    address public priceOracle; //Aave price oracle
    //Reaper contracts
    address public reaperVault; //DAI vault
  
  //Contants
    uint256 public constant PERCENT_DIVISOR = 10000;
    uint256 public contant LoanPercent = 500;

   function _deposit() internal override{
    uint256 wantBal = IERC20(want).balanceOf(address(this));
     if(wantBal > 0){
        // deposit to Aave
         IERC20(want).approve(lendingPool, wantBal);
         ILendingPool(lendingPool).deposit(want, wantBal, address(this), 0); //get some aTokens
         //get price of want
            uint256 wantPrice = IPriceOracleGetter(priceOracle).getAssetPrice(want);
            uint256 totalWantValue = wantBal * wantPrice;
            uint256 borrowAmount = totalWantValue * LoanPercent / PERCENT_DIVISOR; // maitaining 200% collateral
            //Borrow
            ILendingPool(lendingPool).borrow(loanToken, borrowAmount, 2, 0, address(this));
         //Deposit to reaper vault
         //DAI Vault: 0xc0F5DA4FB484CE6d8a6832819299F7cD0D15726E 
          IERC20(loanToken).approve(reaperVault, borrowAmount); //Approve reaper vault to spend DAI.
          IReaperVault(reaperVault).deposit(borrowAmount, address(this));
          //We will get some shares
          //Calculate reaper APY and if it is below 5% then withdraw and repay loan
     }
   } 

     /**
     * @dev Withdraws funds and sends them back to the vault.
     */

    function _withdraw(uint256 _amount) internal override{

     uint256 bal = IERC20(want).balanceOf(address(this));
        if(bal < _amount){
            //Withdraw from reaper vault
            IReaperVault(reaperVault).withdraw(_amount - bal, address(this), address(this));
            //Repay loan
            ILendingPool(lendingPool).repay(loanToken, _amount - bal, 2, address(this));
            //Withdraw from Aave
            ILendingPool(lendingPool).withdraw(want, _amount - bal, address(this));
        }

        IERC20(want).transfer(vault, _amount);

    }

}
