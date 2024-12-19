// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IGameManager {
    /// Custom errors
    error GameNotExists(uint256 gameId);
    error GameAlreadyStarted(uint256 gameId);
    error InsufficientStake();
    error InvalidGameState();
    error NotPlayersTurn();
    error UnauthorizedCaller();

    /// Custom types
    enum GameState {
        PENDING,    // Game created, waiting for opponent
        ACTIVE,     // Game in progress
        COMPLETED,  // Game finished
        CANCELLED   // Game cancelled
    }

    struct Game {
        address whitePlayer;
        address blackPlayer;
        uint256 stakeAmount;
        GameState state;
        uint256 lastMoveTimestamp;
        address currentTurn;
        uint256 totalPooledAmount;
    }

    /// Events
    event GameCreated(
        uint256 indexed gameId,
        address indexed creator,
        uint256 stakeAmount
    );
    
    event GameJoined(
        uint256 indexed gameId,
        address indexed joiner
    );
    
    event GameCompleted(
        uint256 indexed gameId,
        address indexed winner,
        uint256 prizeAmount
    );

    event MoveMade(
        uint256 indexed gameId,
        address indexed player,
        string move
    );

    /// Core functions
    function createGame(uint256 stakeAmount) external payable returns (uint256 gameId);
    function joinGame(uint256 gameId) external payable;
    function executeMove(uint256 gameId, string calldata move) external;
    function claimVictory(uint256 gameId) external;
    function withdrawStake(uint256 gameId) external;
    
    /// View functions
    function getGame(uint256 gameId) external view returns (Game memory);
    function getActiveGames() external view returns (uint256[] memory);
    function getCurrentTurn(uint256 gameId) external view returns (address);
    function getStakeAmount(uint256 gameId) external view returns (uint256);
} 