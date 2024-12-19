// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IGameManager} from "./interfaces/IGameManager.sol";
import {IYieldHandler} from "./interfaces/IYieldHandler.sol";
import {IConsensusLogic} from "./interfaces/IConsensusLogic.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";

/**
 * @title GameManager
 * @notice Manages chess games, including creation, joining, and move execution
 * @dev Implements core game logic and interfaces with yield and consensus modules
 */
contract GameManager is IGameManager, Ownable, ReentrancyGuard, Pausable {
    /// Constants
    uint256 public constant MIN_STAKE = 0.01 ether;
    uint256 public constant MAX_STAKE = 100 ether;
    uint256 public constant GAME_TIMEOUT = 24 hours;

    /// State variables
    uint256 private _gameCounter;
    mapping(uint256 => Game) private _games;
    mapping(uint256 => bool) private _gameExists;
    uint256[] private _activeGames;

    IYieldHandler public yieldHandler;
    IConsensusLogic public consensusLogic;

    /// Constructor
    constructor(address _yieldHandler, address _consensusLogic) Ownable(msg.sender) {
        yieldHandler = IYieldHandler(_yieldHandler);
        consensusLogic = IConsensusLogic(_consensusLogic);
    }

    /// External functions

    /**
     * @notice Creates a new chess game with the specified stake
     * @param stakeAmount Amount of ETH to stake for the game
     * @return gameId Unique identifier for the created game
     */
    function createGame(uint256 stakeAmount) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        returns (uint256) 
    {
        if (msg.value != stakeAmount) revert InsufficientStake();
        if (stakeAmount < MIN_STAKE || stakeAmount > MAX_STAKE) revert InsufficientStake();

        uint256 gameId = ++_gameCounter;
        
        Game storage game = _games[gameId];
        game.whitePlayer = msg.sender;
        game.stakeAmount = stakeAmount;
        game.state = GameState.PENDING;
        game.totalPooledAmount = stakeAmount;
        
        _gameExists[gameId] = true;
        
        // Deposit stake into yield-generating protocol
        yieldHandler.depositToYield{value: stakeAmount}(gameId);
        
        emit GameCreated(gameId, msg.sender, stakeAmount);
        
        return gameId;
    }

    /**
     * @notice Join an existing game by matching the stake amount
     * @param gameId ID of the game to join
     */
    function joinGame(uint256 gameId) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
    {
        if (!_gameExists[gameId]) revert GameNotExists(gameId);
        
        Game storage game = _games[gameId];
        if (game.state != GameState.PENDING) revert GameAlreadyStarted(gameId);
        if (msg.value != game.stakeAmount) revert InsufficientStake();
        
        game.blackPlayer = msg.sender;
        game.state = GameState.ACTIVE;
        game.currentTurn = game.whitePlayer;
        game.lastMoveTimestamp = block.timestamp;
        game.totalPooledAmount += msg.value;
        
        _activeGames.push(gameId);
        
        // Deposit second player's stake
        yieldHandler.depositToYield{value: msg.value}(gameId);
        
        emit GameJoined(gameId, msg.sender);
    }

    /**
     * @notice Execute a move in an active game
     * @param gameId ID of the game
     * @param move Chess move in algebraic notation
     */
    function executeMove(uint256 gameId, string calldata move) 
        external 
        whenNotPaused 
    {
        if (!_gameExists[gameId]) revert GameNotExists(gameId);
        
        Game storage game = _games[gameId];
        if (game.state != GameState.ACTIVE) revert InvalidGameState();
        if (game.currentTurn != msg.sender) revert NotPlayersTurn();
        
        // Update game state
        game.currentTurn = (msg.sender == game.whitePlayer) ? game.blackPlayer : game.whitePlayer;
        game.lastMoveTimestamp = block.timestamp;
        
        emit MoveMade(gameId, msg.sender, move);
    }

    /// View functions

    function getGame(uint256 gameId) external view returns (Game memory) {
        if (!_gameExists[gameId]) revert GameNotExists(gameId);
        return _games[gameId];
    }

    function getActiveGames() external view returns (uint256[] memory) {
        return _activeGames;
    }

    function getCurrentTurn(uint256 gameId) external view returns (address) {
        if (!_gameExists[gameId]) revert GameNotExists(gameId);
        return _games[gameId].currentTurn;
    }

    function getStakeAmount(uint256 gameId) external view returns (uint256) {
        if (!_gameExists[gameId]) revert GameNotExists(gameId);
        return _games[gameId].stakeAmount;
    }

    /// Admin functions

    function setYieldHandler(address _yieldHandler) external onlyOwner {
        yieldHandler = IYieldHandler(_yieldHandler);
    }

    function setConsensusLogic(address _consensusLogic) external onlyOwner {
        consensusLogic = IConsensusLogic(_consensusLogic);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
} 