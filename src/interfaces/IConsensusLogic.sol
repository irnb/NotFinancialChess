// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IConsensusLogic {
    /// Custom errors
    error InvalidMove();
    error VotingClosed();
    error InsufficientShares();
    error AlreadyVoted();

    /// Custom types
    struct MoveProposal {
        string move;
        uint256 votingEndsAt;
        uint256 totalVotes;
        bool executed;
        mapping(address => uint256) votes;
    }

    /// Events
    event MoveProposed(
        uint256 indexed gameId,
        uint256 indexed proposalId,
        string move,
        address proposer
    );

    event VoteCast(
        uint256 indexed gameId,
        uint256 indexed proposalId,
        address voter,
        uint256 weight
    );

    event MoveExecuted(
        uint256 indexed gameId,
        uint256 indexed proposalId,
        string move
    );

    /// Core functions
    function proposeMove(uint256 gameId, string calldata move) external returns (uint256 proposalId);
    function vote(uint256 gameId, uint256 proposalId, uint256 amount) external;
    function executeTopMove(uint256 gameId) external;
    
    /// View functions
    function getProposal(uint256 gameId, uint256 proposalId) external view returns (
        string memory move,
        uint256 votingEndsAt,
        uint256 totalVotes,
        bool executed
    );
    function getVoteWeight(address voter, uint256 gameId) external view returns (uint256);
    function getActiveProposals(uint256 gameId) external view returns (uint256[] memory);
} 