// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IYieldHandler} from "./interfaces/IYieldHandler.sol";
import {IPool} from "lib/aave-v3-core/contracts/interfaces/IL2Pool.sol";
import {IPoolAddressesProvider} from "lib/aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {Math} from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

/**
 * @title YieldHandler
 * @notice Manages yield generation through Aave lending protocol
 * @dev Implements yield strategies for staked ETH in games
 */
contract YieldHandler is IYieldHandler, Ownable, ReentrancyGuard, Pausable {
    /// Constants
    uint256 private constant PRECISION = 1e18;
    
    /// State variables
    IPool public aavePool;
    mapping(uint256 => uint256) private _gameShares;
    uint256 private _totalShares;
    uint256 private _totalValueLocked;

    /// Events
    event StrategyUpdated(address indexed newStrategy);
    
    /// Constructor
    constructor(address _aaveAddressProvider) Ownable(msg.sender) {
        IPoolAddressesProvider provider = IPoolAddressesProvider(_aaveAddressProvider);
        aavePool = IPool(provider.getPool());
    }

    /// External functions

    /**
     * @notice Deposits ETH into Aave for yield generation
     * @param gameId ID of the game the deposit is for
     */
    function depositToYield(uint256 gameId) 
        external 
        payable 
        override 
        nonReentrant 
        whenNotPaused 
    {
        if (msg.value == 0) revert InsufficientLiquidity();

        uint256 shares;
        if (_totalValueLocked == 0) {
            shares = msg.value;
        } else {
            shares = (msg.value * _totalShares) / _totalValueLocked;
        }

        _gameShares[gameId] += shares;
        _totalShares += shares;
        _totalValueLocked += msg.value;

        // Deposit to Aave
        aavePool.supply{value: msg.value}(address(this), msg.value, address(this), 0);

        emit YieldDeposited(gameId, msg.value, shares);
    }

    /**
     * @notice Withdraws ETH and accumulated yield
     * @param gameId ID of the game to withdraw for
     * @param amount Amount to withdraw
     */
    function withdrawFromYield(uint256 gameId, uint256 amount) 
        external 
        override 
        nonReentrant 
        whenNotPaused 
    {
        uint256 gameBalance = getYieldBalance(gameId);
        if (amount > gameBalance) revert InsufficientLiquidity();

        uint256 sharesToBurn = (amount * _totalShares) / _totalValueLocked;
        _gameShares[gameId] -= sharesToBurn;
        _totalShares -= sharesToBurn;
        _totalValueLocked -= amount;

        // Withdraw from Aave
        aavePool.withdraw(address(this), amount, address(this));
        
        // Transfer ETH to caller
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert YieldStrategyFailed();

        emit YieldWithdrawn(gameId, amount, sharesToBurn);
    }

    /**
     * @notice Harvests yield for a specific game
     * @param gameId ID of the game to harvest yield for
     * @return yieldAmount Amount of yield harvested
     */
    function harvestYield(uint256 gameId) 
        external 
        override 
        nonReentrant 
        returns (uint256 yieldAmount) 
    {
        uint256 currentBalance = getYieldBalance(gameId);
        uint256 initialBalance = (_gameShares[gameId] * _totalValueLocked) / _totalShares;
        yieldAmount = currentBalance - initialBalance;

        if (yieldAmount > 0) {
            // Withdraw yield from Aave
            aavePool.withdraw(address(this), yieldAmount, address(this));
            
            // Transfer yield to caller
            (bool success, ) = msg.sender.call{value: yieldAmount}("");
            if (!success) revert YieldStrategyFailed();

            emit YieldHarvested(gameId, yieldAmount);
        }
    }

    /// View functions

    function getYieldBalance(uint256 gameId) public view override returns (uint256) {
        if (_totalShares == 0) return 0;
        return (_gameShares[gameId] * _totalValueLocked) / _totalShares;
    }

    function getExpectedYield(uint256 gameId) external view override returns (uint256) {
        uint256 currentBalance = getYieldBalance(gameId);
        uint256 initialBalance = (_gameShares[gameId] * _totalValueLocked) / _totalShares;
        return currentBalance > initialBalance ? currentBalance - initialBalance : 0;
    }

    function getTotalValueLocked() external view override returns (uint256) {
        return _totalValueLocked;
    }

    /// Admin functions

    function setAavePool(address _newPool) external onlyOwner {
        aavePool = IPool(_newPool);
        emit StrategyUpdated(_newPool);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// Receive function to accept ETH
    receive() external payable {}
} 