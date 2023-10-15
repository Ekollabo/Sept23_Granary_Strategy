// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./interfaces/IStrategy.sol";
import "openzeppelin/access/Ownable.sol";
import "openzeppelin/utils/ReentrancyGuard.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract MaxiVault is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public strategy;
    uint256 public depositFee;
    uint256 public tvlCap;
    uint256 public dynamicTvlCapThreshold;
    bool public initialized = false;
    uint256 public constructionTime;
    IERC20 public token;

    mapping(address => uint256) public cumulativeDeposits;
    mapping(address => uint256) public cumulativeWithdrawals;

    event TermsAccepted(address user);
    event TvlCapUpdated(uint256 newTvlCap);
    event DepositsIncremented(address user, uint256 amount, uint256 total);
    event WithdrawalsIncremented(address user, uint256 amount, uint256 total);

    constructor(address _token, string memory _name, string memory _symbol, uint256 _depositFee, uint256 _tvlCap, uint256 _dynamicTvlCapThreshold)
        ERC20(_name, _symbol)
        Ownable(msg.sender)
    {
        token = IERC20(_token);
        constructionTime = block.timestamp;
        depositFee = _depositFee;
        tvlCap = _tvlCap;
        dynamicTvlCapThreshold = _dynamicTvlCapThreshold;
    }

    function initialize(address _strategy) public onlyOwner returns (bool) {
        require(!initialized, "Contract is already initialized.");
        require(block.timestamp <= (constructionTime + 1200), "Initialization period over.");
        strategy = _strategy;
        initialized = true;
        return true;
    }

    function available() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getPricePerFullShare() public view returns (uint256) {
        return totalSupply() == 0 ? 1e18 : (balance() * 1e18) / totalSupply();
    }

    function depositAll() external {
        deposit(token.balanceOf(msg.sender));
    }

    function deposit(uint256 _amount) public nonReentrant {
        require(_amount != 0, "Please provide an amount");
        uint256 _pool = balance();
        require(_pool + _amount <= tvlCap, "Vault is full!");

        uint256 _before = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _after = token.balanceOf(address(this));
        _amount = _after - _before;
        uint256 _amountAfterDeposit = (_amount * (PERCENT_DIVISOR - depositFee)) / PERCENT_DIVISOR;
        uint256 shares = totalSupply() == 0 ? _amountAfterDeposit : (_amountAfterDeposit * totalSupply()) / _pool;
        _mint(msg.sender, shares);
        earn();
        incrementDeposits(_amount);
    }

    function earn() public {
        uint256 _bal = available();
        token.safeTransfer(strategy, _bal);
        IStrategy(strategy).deposit();
    }

    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    function withdraw(uint256 _shares) public nonReentrant {
        require(_shares > 0, "Please provide an amount");
        uint256 r = (balance() * _shares) / totalSupply();
        _burn(msg.sender, _shares);

        uint256 b = token.balanceOf(address(this));
        if (b < r) {
            uint256 _withdraw = r - b;
            IStrategy(strategy).withdraw(_withdraw, msg.sender);
            uint256 _after = token.balanceOf(address(this));
            uint256 _diff = _after - b;
            if (_diff < _withdraw) {
                r = b + _diff;
            }
        }
        token.safeTransfer(msg.sender, r);
        incrementWithdrawals(r);
    }

    function updateDepositFee(uint256 fee) public onlyOwner {
        depositFee = fee;
    }

    function updateTvlCap(uint256 _newTvlCap) public onlyOwner {
        tvlCap = _newTvlCap;
        emit TvlCapUpdated(tvlCap);
    }

    function removeTvlCap() external onlyOwner {
        updateTvlCap(type(uint256).max);
    }

    function setDynamicTvlCapThreshold(uint256 _threshold) public onlyOwner {
        require(_threshold <= PERCENT_DIVISOR, "Threshold must be <= 10000");
        dynamicTvlCapThreshold = _threshold;
    }

    function incrementDeposits(uint256 _amount) internal returns (bool) {
        uint256 initial = cumulativeDeposits[tx.origin];
        uint256 newTotal = initial + _amount;
        cumulativeDeposits[tx.origin] = newTotal;
        emit DepositsIncremented(tx.origin, _amount, newTotal);
        return true;
    }

    function incrementWithdrawals(uint256 _amount) internal returns (bool) {
        uint256 initial = cumulativeWithdrawals[tx.origin];
        uint256 newTotal = initial + _amount;
        cumulativeWithdrawals[tx.origin] = newTotal;
        emit WithdrawalsIncremented(tx.origin, _amount, newTotal);
        return true;
    }

    function inCaseTokensGetStuck(address _token) external onlyOwner {
        require(_token != address(token), "Invalid token");
        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(msg.sender, amount);
    }
}
