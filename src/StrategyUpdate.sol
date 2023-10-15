// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IDataProvider} from "./interfaces/IDataProvider.sol";
import {IAaveIncentives} from "./interfaces/IAaveIncentives.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {IReaperVault} from "./interfaces/IReaperVault.sol";
import {IMaxiVault} from "./interfaces/IMaxiVault.sol";
import {console2} from "forge-std/console2.sol";
import {Math} from "openzeppelin/utils/math/Math.sol";

interface IERC20Extended is IERC20 {
    function decimals() external view returns (uint8);
}

contract Strategy is Ownable {
    using SafeERC20 for IERC20Extended;

    address public vault;

    // tokens used
    address public want;
    address public loanToken;
    address public aToken;
    // Aave contracts
    address public lendingPool;
    address public dataProvider;
    address public aaveIncentives;
    address public priceOracle;
    // Reaper contracts
    address public reaperVault;

    // Constants
    uint256 public constant PRECISION = 100;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;
    uint256 FEED_PRECISION = 1e10;
    uint256 MIN_HEALTH_FACTOR = 1500000000000000000;

    constructor(
        address _vault,
        address _want,
        address _loanToken,
        address _lendingPool,
        address _dataProvider,
        address _aaveIncentives,
        address _priceOracle,
        address _reaperVault
    ) Ownable(msg.sender) {
        vault = _vault;
        want = _want;
        loanToken = _loanToken;
        lendingPool = _lendingPool;
        dataProvider = _dataProvider;
        aaveIncentives = _aaveIncentives;
        priceOracle = _priceOracle;
        reaperVault = _reaperVault;

        (aToken,,) = IDataProvider(dataProvider).getReserveTokensAddresses(address(want));
    }

    function deposit() external {
        require(msg.sender == vault, "!vault");
        _supplyAndBorrow();
        _depositToReaper();
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == vault, "!vault");
        _adjustPosition();
        uint256 currBal = _balanceOfWant();

        if (currBal < _amount) {
            uint256 loanTokenAmountToWithdraw = _convertToLoanToken(_amount - currBal);
            IReaperVault(reaperVault).withdraw(loanTokenAmountToWithdraw, address(this), address(this));
            ILendingPool(lendingPool).repay(loanToken, loanTokenAmountToWithdraw, 2, address(this));
            ILendingPool(lendingPool).withdraw(want, _amount - currBal, address(this));
            _adjustPosition();
        }
        IERC20Extended(want).safeTransfer(vault, _amount);
    }

    function balanceOf() public view returns (uint256) {
        return _balanceOfWant() + _balanceOfPool() + _earned();
    }

    function adjustPosition() public view onlyOwner {
        _adjustPosition();
    }

    /* --------------------------- INTERNAL FUNCTIONS --------------------------- */

    function _supplyAndBorrow() internal {
        uint256 wantBal = _balanceOfWant();
        if (wantBal != 0) {
            IERC20Extended(want).approve(lendingPool, wantBal);
            ILendingPool(lendingPool).deposit(want, wantBal, address(this), 0);
            uint256 borrowAmount = _calculateBorrowAmount(wantBal);
            ILendingPool(lendingPool).borrow(loanToken, borrowAmount, 2, 0, address(this));
            uint256 healthFactor = _checkHealthFactor();
            if (healthFactor < MIN_HEALTH_FACTOR) {
                _adjustPosition();
            }
        }
    }

    function _calculateBorrowAmount(uint256 _want) internal view returns (uint256) {
        uint256 loanTokenAmount = _convertToLoanToken(_want);
        return loanTokenAmount;
    }

    function _checkHealthFactor() internal view returns (uint256) {
        (,,,,, uint256 _healthFactor) = ILendingPool(lendingPool).getUserAccountData(address(this));
        return _healthFactor;
    }

    function _depositToReaper() internal {
        uint256 loanTokenBal = IERC20Extended(loanToken).balanceOf(address(this));
        if (loanTokenBal != 0) {
            IERC20Extended(loanToken).approve(reaperVault, loanTokenBal);
            IReaperVault(reaperVault).deposit(loanTokenBal, address(this));
        }
    }

    function _adjustPosition() internal view {
        (uint256 supplyBal, uint256 borrowBal) = _userReserves(want);
        uint256 healthFactor = _checkHealthFactor();
        if (supplyBal == 0 && borrowBal == 0) {
            // No position
            // return;
        }

        if (supplyBal != 0 && borrowBal != 0) {
            // We have a position
            if (healthFactor < MIN_HEALTH_FACTOR) {
                // get funds and repay some loan and check position again if it has increased or not
                // return;
            }
            if (healthFactor > MIN_HEALTH_FACTOR) {
                // We have a profit
                //May be we can take more loan and deposit to reaper
                // return;
            }
        }
    }

    /* ----------------------------- VIEW FUNCTIONS INTERNAL ----------------------------- */

    function _userReserves(address asset) internal view returns (uint256, uint256) {
        (uint256 supplyAmount,, uint256 variableRateBorrowAmount,,,,,,) =
            IDataProvider(dataProvider).getUserReserveData(asset, address(this));
        return (supplyAmount, variableRateBorrowAmount);
    }

    function _balanceOfPool() internal view returns (uint256) {
        (uint256 supplyAmount, uint256 borrowAmount) = _userReserves(want);
        return supplyAmount - borrowAmount;
    }

    function _debtInPool() internal view returns (uint256) {
        ( /*uint256 supplyAmount*/ , uint256 borrowAmount) = _userReserves(loanToken);
        return borrowAmount;
    }

    function _assetStakedInVault() internal view returns (uint256) {
        IReaperVault _reaperVault = IReaperVault(reaperVault);
        return _reaperVault.convertToAssets(_reaperVault.balanceOf(address(this)));
    }

    function _balanceOfWant() internal view returns (uint256) {
        return IERC20Extended(want).balanceOf(address(this));
    }

    function _earned() internal view returns (uint256) {
        uint256 reaperBal = _assetStakedInVault();
        uint256 debt = _debtInPool();

        if (reaperBal <= debt) {
            // We have a loss or no profit
            return 0; // to prevent underflow if loss
        }
        uint256 diff = reaperBal - debt;
        uint256 wantPrice = IPriceOracle(priceOracle).getAssetPrice(want) * FEED_PRECISION; // covert to 18 decimals
        uint256 profitInWant = diff / wantPrice; //convert to want
        return profitInWant / FEED_PRECISION; // Normalize to 8 decimals
    }

    function _convertToLoanToken(uint256 _wantAmount) internal view returns (uint256) {
        uint256 remainingDecimals = 18 - IERC20Extended(want).decimals();
        uint256 decimals = 10 ** remainingDecimals;

        uint256 wantTokenPrice = IPriceOracle(priceOracle).getAssetPrice(want) * FEED_PRECISION; // covert to 18 decimals

        uint256 loanTokenPrice = IPriceOracle(priceOracle).getAssetPrice(loanToken) * FEED_PRECISION; // covert to 18 decimals
        uint256 loanTokenAmount;

        if (decimals != 0) {
            loanTokenAmount = _wantAmount * decimals * wantTokenPrice / loanTokenPrice;
        } else {
            loanTokenAmount = _wantAmount * wantTokenPrice / loanTokenPrice;
        }
        return loanTokenAmount / 2;
    }
    /* ------------------------------- PUBLIC VIEW FUNCTIONS ------------------------------ */
    function balanceOf() public view returns (uint256) {
        return _balanceOfWant() + _balanceOfPool() + _earned();
    }

    function adjustPosition() public view onlyOwner {
        _adjustPosition();
        //Why is this public view? shouldn't it be external (if we want to automatically adjust position)
    }
    /* ------------------------------- ADDITIONAL FUNCTIONS ------------------------------ */
    //Fee Handling
    uint256 constant FEE_PERCENT = 1; // Set desired fee percentage (Whatever percentage the team agrees on)

    function deposit() external {
        require(msg.sender == vault, "!vault");
        _supplyAndBorrow();

        // Calculate and deduct a fee from the earned yield
        uint256 earnedBeforeFee = _earned();
        uint256 fee = earnedBeforeFee * FEE_PERCENT / 100; // Calculate a percentage-based fee
        uint256 earnedAfterFee = earnedBeforeFee - fee;

        // Continue with depositing the remaining amount into the Reaper Vault
        _depositToReaper();

        // Collect the fee for the strategy
        if (fee > 0) {
            IERC20Extented(want).safeTransfer(owner(), fee);
        }
    }
    //Security Measures (Emergency Stop Function)
    address public admin;

    constructor(
        address _vault,
        // ...
        address _admin // Specify an admin address
    ) Ownable(msg.sender) {
        vault = _vault;
        // ...
        admin = _admin;
    }

    function emergencyStop() public {
        require(msg.sender == admin, "!admin");
        // Add code to halt certain functions and protect the strategy
    }
    //Some logic for the _adjustPosition function
    function _adjustPosition() internal {
        (uint256 supplyBal, uint256 borrowBal) = _userReserves(want);
        uint256 healthFactor = _checkHealthFactor();
        if (supplyBal == 0 && borrowBal == 0) {
            // No position
            // Implement actions when there is no position (optional)
        }

        if (supplyBal != 0 && borrowBal != 0) {
            // We have a position
            if (healthFactor < MIN_HEALTH_FACTOR) {
                // Position is at risk, take action to improve it
                // For example, we can get funds and repay some loan
                // The following code is an example and should be customized:
                uint256 additionalFunds = 1000; // Customize the amount of funds to get
                uint256 loanToRepay = 500; // Customize the amount of loan to repay

                // Get additional funds (assuming want is a token address)
                IERC20Extented(want).transferFrom(msg.sender, address(this), additionalFunds);

                // Repay some loan (assuming loanToken is a token address)
                ILendingPool(lendingPool).repay(loanToken, loanToRepay, 2, address(this));

                // Check position again if it has improved (optional)
                // Perform additional checks or actions here
            }
            if (healthFactor > MIN_HEALTH_FACTOR) {
                // We have a profit
                // Take more loans and deposit to reaper (customize this logic)
                // For example, we can implement logic to take more loans and deposit them into a "reaper"
            }
        }
    }




}



