// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Errors {
    error ZeroAddress();
    error ZeroStake();
    error InvalidRounds(uint8 rounds);
    error InvalidMultiplier(uint16 multiplierBps);
    error InvalidRevealTimeout(uint64 revealTimeout);

    error ZeroCardId();
    error InvalidCardStats();
    error InvalidElement(uint8 element);
    error CardAlreadyExists(uint256 cardId);
    error CardNotFound(uint256 cardId);

    error MatchNotFound(uint256 matchId);
    error InvalidState(uint256 matchId);
    error NotPlayer(uint256 matchId);
    error SelfMatch();
    error InvalidCommit();
    error AlreadyCommitted();
    error AlreadyRevealed();
    error InvalidReveal();
    error InvalidLineupLength(uint8 expected, uint256 provided);
    error DuplicateCardId(uint256 cardId);
    error UnknownCardId(uint256 cardId);

    error RevealWindowNotStarted(uint256 matchId);
    error RevealDeadlineNotPassed(uint256 matchId, uint64 revealDeadline);
    error RevealDeadlinePassed(uint256 matchId, uint64 revealDeadline);
    error AlreadyResolved(uint256 matchId);
}
