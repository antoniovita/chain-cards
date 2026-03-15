// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./Base.t.sol";
import {Errors} from "../src/libraries/Errors.sol";
import {Types} from "../src/libraries/Types.sol";

contract DuelGameCommitRevealTest is BaseTest {
    function test_RevertReveal_WrongSalt() public {
        Types.MatchConfig memory cfg = _defaultConfig(3);

        uint256[] memory aLineup = new uint256[](3);
        aLineup[0] = 1;
        aLineup[1] = 2;
        aLineup[2] = 3;

        uint256[] memory bLineup = new uint256[](3);
        bLineup[0] = 3;
        bLineup[1] = 4;
        bLineup[2] = 5;

        uint256 matchId = game.nextMatchId();
        bytes32 aSalt = keccak256("a");
        bytes32 bSalt = keccak256("b");
        bytes32 aCommit = _commit(matchId, alice, aLineup, aSalt);
        bytes32 bCommit = _commit(matchId, bob, bLineup, bSalt);

        vm.prank(alice);
        game.createChallenge(cfg, aCommit);
        vm.prank(bob);
        game.acceptChallenge(matchId, bCommit);

        vm.prank(alice);
        vm.expectRevert(Errors.InvalidReveal.selector);
        game.reveal(matchId, aLineup, keccak256("wrong"));
    }

    function test_RevertReveal_WrongLineup() public {
        Types.MatchConfig memory cfg = _defaultConfig(3);

        uint256[] memory aLineup = new uint256[](3);
        aLineup[0] = 1;
        aLineup[1] = 2;
        aLineup[2] = 3;

        uint256[] memory bLineup = new uint256[](3);
        bLineup[0] = 3;
        bLineup[1] = 4;
        bLineup[2] = 5;

        uint256 matchId = game.nextMatchId();
        bytes32 aSalt = keccak256("a");
        bytes32 bSalt = keccak256("b");
        bytes32 aCommit = _commit(matchId, alice, aLineup, aSalt);
        bytes32 bCommit = _commit(matchId, bob, bLineup, bSalt);

        vm.prank(alice);
        game.createChallenge(cfg, aCommit);
        vm.prank(bob);
        game.acceptChallenge(matchId, bCommit);

        uint256[] memory wrong = new uint256[](3);
        wrong[0] = 1;
        wrong[1] = 2;
        wrong[2] = 4;

        vm.prank(alice);
        vm.expectRevert(Errors.InvalidReveal.selector);
        game.reveal(matchId, wrong, aSalt);
    }

    function test_RevertReveal_DuplicateCardIds() public {
        Types.MatchConfig memory cfg = _defaultConfig(3);

        uint256[] memory aLineup = new uint256[](3);
        aLineup[0] = 1;
        aLineup[1] = 1;
        aLineup[2] = 2;

        uint256[] memory bLineup = new uint256[](3);
        bLineup[0] = 3;
        bLineup[1] = 4;
        bLineup[2] = 5;

        uint256 matchId = game.nextMatchId();
        bytes32 aSalt = keccak256("a");
        bytes32 bSalt = keccak256("b");
        bytes32 aCommit = _commit(matchId, alice, aLineup, aSalt);
        bytes32 bCommit = _commit(matchId, bob, bLineup, bSalt);

        vm.prank(alice);
        game.createChallenge(cfg, aCommit);
        vm.prank(bob);
        game.acceptChallenge(matchId, bCommit);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.DuplicateCardId.selector, uint256(1)));
        game.reveal(matchId, aLineup, aSalt);
    }

    function test_RevertReveal_UnknownCardId() public {
        Types.MatchConfig memory cfg = _defaultConfig(3);

        uint256[] memory aLineup = new uint256[](3);
        aLineup[0] = 1;
        aLineup[1] = 2;
        aLineup[2] = 999;

        uint256[] memory bLineup = new uint256[](3);
        bLineup[0] = 3;
        bLineup[1] = 4;
        bLineup[2] = 5;

        uint256 matchId = game.nextMatchId();
        bytes32 aSalt = keccak256("a");
        bytes32 bSalt = keccak256("b");
        bytes32 aCommit = _commit(matchId, alice, aLineup, aSalt);
        bytes32 bCommit = _commit(matchId, bob, bLineup, bSalt);

        vm.prank(alice);
        game.createChallenge(cfg, aCommit);
        vm.prank(bob);
        game.acceptChallenge(matchId, bCommit);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.UnknownCardId.selector, uint256(999)));
        game.reveal(matchId, aLineup, aSalt);
    }

    function test_RevertReveal_DoubleReveal() public {
        Types.MatchConfig memory cfg = _defaultConfig(3);

        uint256[] memory aLineup = new uint256[](3);
        aLineup[0] = 1;
        aLineup[1] = 2;
        aLineup[2] = 3;

        uint256[] memory bLineup = new uint256[](3);
        bLineup[0] = 3;
        bLineup[1] = 4;
        bLineup[2] = 5;

        uint256 matchId = game.nextMatchId();
        bytes32 aSalt = keccak256("a");
        bytes32 bSalt = keccak256("b");
        bytes32 aCommit = _commit(matchId, alice, aLineup, aSalt);
        bytes32 bCommit = _commit(matchId, bob, bLineup, bSalt);

        vm.prank(alice);
        game.createChallenge(cfg, aCommit);
        vm.prank(bob);
        game.acceptChallenge(matchId, bCommit);

        vm.prank(alice);
        game.reveal(matchId, aLineup, aSalt);

        vm.prank(alice);
        vm.expectRevert(Errors.AlreadyRevealed.selector);
        game.reveal(matchId, aLineup, aSalt);
    }
}

