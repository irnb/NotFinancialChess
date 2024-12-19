// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IYieldHandler {
    /// Custom errors
    error InsufficientLiquidity();
    error UnsupportedToken();
    error YieldStrategyFailed();

    /// Events
    event YieldDeposited(
        uint256 indexed gameId,
        uint256 amount,
        uint256 shares
    );

    event YieldWithdrawn(
        uint256 indexed gameId,
        uint256 amount,
        uint256 shares
    );

    event YieldHarvested(
        uint256 indexed gameId,
        uint256 yieldAmount
    );

    /// Core functions
    function depositToYield(uint256 gameId) external payable;
    function withdrawFromYield(uint256 gameId, uint256 amount) external;
    function harvestYield(uint256 gameId) external returns (uint256);
    
    /// View functions
    function getYieldBalance(uint256 gameId) external view returns (uint256);
    function getExpectedYield(uint256 gameId) external view returns (uint256);
    function getTotalValueLocked() external view returns (uint256);
} 