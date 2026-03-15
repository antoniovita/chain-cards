// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./Base.t.sol";
import {Errors} from "../src/libraries/Errors.sol";
import {Types} from "../src/libraries/Types.sol";

contract DuelGameTimeoutsTest is BaseTest {
    function test_CancelUnaccepted_RefundsCreator() public {
        Types.MatchConfig memory cfg = _defaultConfig(3);

        uint256[] memory aLineup = new uint256[](3);
        aLineup[0] = 1;
        aLineup[1] = 2;
        aLineup[2] = 3;

        uint256 matchId = game.nextMatchId();
        bytes32 aSalt = keccak256("a");
        bytes32 aCommit = _commit(matchId, alice, aLineup, aSalt);

        uint256 beforeBal = token.balanceOf(alice);
        vm.prank(alice);
        game.createChallenge(cfg, aCommit);
        assertEq(token.balanceOf(alice), beforeBal - cfg.stake);

        vm.prank(alice);
        game.cancelUnaccepted(matchId);
        assertEq(token.balanceOf(alice), beforeBal);
    }

    function test_ClaimForfeit_OneRevealed_WinsPot() public {
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

        uint64 deadline;
        (, , , , , , deadline) = game.getMatchInfo(matchId);

        uint256 aliceBefore = token.balanceOf(alice);
        vm.prank(alice);
        game.reveal(matchId, aLineup, aSalt);

        vm.warp(uint256(deadline) + 1);
        game.claimForfeit(matchId);

        uint256 pot = uint256(cfg.stake) * 2;
        assertEq(token.balanceOf(alice), aliceBefore + pot);
    }

    function test_ClaimForfeit_NoneRevealed_RefundsBoth() public {
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

        uint256 aliceBefore = token.balanceOf(alice);
        uint256 bobBefore = token.balanceOf(bob);

        vm.prank(alice);
        game.createChallenge(cfg, aCommit);
        vm.prank(bob);
        game.acceptChallenge(matchId, bCommit);

        uint64 deadline;
        (, , , , , , deadline) = game.getMatchInfo(matchId);
        vm.warp(uint256(deadline) + 1);
        game.claimForfeit(matchId);

        assertEq(token.balanceOf(alice), aliceBefore);
        assertEq(token.balanceOf(bob), bobBefore);
    }

    function test_RevertReveal_AfterDeadline() public {
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

        uint64 deadline;
        (, , , , , , deadline) = game.getMatchInfo(matchId);
        vm.warp(uint256(deadline) + 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.RevealDeadlinePassed.selector, matchId, deadline));
        game.reveal(matchId, aLineup, aSalt);
    }
}
