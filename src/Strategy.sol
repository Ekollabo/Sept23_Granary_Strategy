// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IDataProvider} from "./interfaces/IDataProvider.sol";
import {IAaveIncentives} from "./interfaces/IAaveIncentives.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {IReaperVault} from "./interfaces/IReaperVault.sol";
import {IMaxiVault} from "./interfaces/IMaxiVault.sol";

contract Strategy is Ownable {
    using SafeERC20 for IERC20;

    address payable public vault;

    // tokens used
    IERC20 public want;
    IERC20 public loanToken;
    IERC20 public aToken;
    // Aave contracts
    ILendingPool public lendingPool;
    IDataProvider public dataProvider;
    IAaveIncentives public aaveIncentives;
    IPriceOracle public priceOracle;
    //Reaper contracts
    IReaperVault public reaperVault;

    //Contants
    uint256 public constant PRECISION = 100;
    uint256 public constant LIQUIDATION_TRESHOLD = 50;
    uint256 FEED_PRECISION = 1e10;
    uint256 MIN_HEALTH_FACTOR = 1500000000000000000;

    constructor(
        address _vault,
        address _want,
        address _loanToken,
        address _aToken,
        address _lendingPool,
        address _dataProvider,
        address _aaveIncentives,
        address _priceOracle,
        address _reaperVault
    ) {
        vault = IMaxiVault(payable(_vault));
        want = IERC20(_want);
        loanToken = IERC20(_loanToken);
        lendingPool = ILendingPool(_lendingPool);
        dataProvider = IDataProvider(_dataProvider);
        aaveIncentives = IAaveIncentives(_aaveIncentives);
        priceOracle = IPriceOracle(_priceOracle);
        reaperVault = IReaperVault(_reaperVault);

        (_aToken,,) = IDataProvider(dataProvider).getReserveTokensAddresses(want);
        aToken = IERC20(_aToken);
    }

    function deposit() external {
        require(msg.sender == vault, "!vault");
        _monitorPositionAndAdjust();
        _supplyAndBorrow();
        _depositToReaper();
    }

    function _supplyAndBorrow() internal {
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        if (wantBal != 0) {
            ILendingPool(lendingPool).deposit(want, wantBal, address(this), 0);
            uint256 borrowAmount = _calculateBorrowAmount(wantBal); // get 50% of want in loanToken
            ILendingPool(lendingPool).borrow(loanToken, borrowAmount, 2, 0, address(this));
            uint256 healthFactor = _checkHealthFactor();
            if (healthFactor < MIN_HEALTH_FACTOR) {
                //TODO: Adjust position
                return;
            }
        }
    }

    function _calculateBorrowAmount(uint256 _want) internal view returns (uint256) {
        uint256 half = _want / 2;
        uint256 loanTokenAmount = _convertToLoanToken(half);
        return loanTokenAmount;
    }

    function _checkHealthFactor() internal view returns (uint256 healthFactor) {
        (,,,,, uint256 healthFactor) = ILendingPool(lendingPool).getUserAccountData(address(this));
    }

    function _depositToReaper() internal {
        uint256 loanTokenBal = loanToken.balanceOf(address(this));
        if (loanTokenBal != 0) {
            loanToken.approve(reaperVault, loanTokenBal);
            IReaperVault(reaperVault).deposit(loanTokenBal, address(this), address(this));
        }
    }

    /**
     * @dev Withdraws funds and sends them back to the vault.
     */
    function withdraw(uint256 _amount) external {
        require(msg.sender == vault, "!vault");
        _monitorPositionAndAdjust();
        uint256 currBal = _balanceOfWant();

        if (currBal < _amount) {
            uint256 loanTokenAmountToWithdraw = _convertToLoanToken(_amount - currBal);
            reaperVault.withdraw(loanTokenAmountToWithdraw, address(this), address(this));
            lendingPool.repay(loanToken, loanTokenAmountToWithdraw, 2, address(this));
            lendingPool.withdraw(want, _amount - currBal, address(this));
            _monitorPositionAndAdjust();
        }
        want.safeTransfer(vault, _amount);
    }

    /* --------------------------- INTERNAL FUNCTIONS --------------------------- */

    function _monitorPositionAndAdjust() internal {
        (uint256 supplyBal, uint256 borrowBal) = _userReserves(want);
        uint256 healthFactor = _checkHealthFactor();
        if (supplyBal == 0 && borrowBal == 0) {
            // No position
            return;
        }

        if (supplyBal != 0 && borrowBal != 0) {
            // We have a position
            if (healthFactor < MIN_HEALTH_FACTOR) {
                // get funds and repay some loan and check position again if it has increased or not
                return;
            }
            if (healthFactor > MIN_HEALTH_FACTOR) {
                // We have a profit
                //May be we can take more loan and deposit to reaper
                return;
            }
        }
    }

    /* ----------------------------- VIEW FUNCTIONS INTERNAL ----------------------------- */
    // return supply and borrow balance
    function _userReserves(address asset) internal view returns (uint256, uint256) {
        (uint256 supplyBal,, uint256 borrowBal,,,,,,) =
            IDataProvider(dataProvider).getUserReserveData(asset, address(this));
        return (supplyBal, borrowBal);
    }

    function _balanceOfPool() internal view returns (uint256) {
        (uint256 supplyBal, uint256 borrowBal) = _userReserves(want);
        return supplyBal - borrowBal;
    }

    function _debtInPool() internal view returns (uint256) {
        (, uint256 borrowBal,,,,,,,) = _userReserves(loanToken);
        return borrowBal;
    }

    function _assetStakedInVault() internal view returns (uint256) {
        return IReaperVault(reaperVault).convertToAssets(reaperVault.balanceOf(address(this)));
    }

    function _balanceOfWant() internal view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
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
        uint256 decimals = 1e18 - want.decimals();

        uint256 wantTokenPrice = IPriceOracle(priceOracle).getAssetPrice(want) * FEED_PRECISION; // covert to 18 decimals
        uint256 loanTokenPrice = IPriceOracle(priceOracle).getAssetPrice(loanToken) * FEED_PRECISION; // covert to 18 decimals

        uint256 loanTokenAmount;

        if (decimals != 0) {
            loanTokenAmount = _wantAmount * decimals * wantTokenPrice / loanTokenPrice;
        } else {
            loanTokenAmount = _wantAmount * wantTokenPrice / loanTokenPrice;
        }
        return loanTokenAmount;
    }

    /* ------------------------------- PUBLIC VIEW FUNCTIONS ------------------------------ */

    function balanceOf() public view returns (uint256) {
        return _balanceOfWant() + _balanceOfPool() + _earned();
    }

    function monitorPositionAndAdjust() public view onlyOwner returns (uint256) {
        return _monitorPositionAndAdjust();
    }
}
