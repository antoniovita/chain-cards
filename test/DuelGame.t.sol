// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./Base.t.sol";
import {Errors} from "../src/libraries/Errors.sol";
import {Types} from "../src/libraries/Types.sol";
import {ICardRegistry} from "../src/interfaces/ICardRegistry.sol";

contract DuelGameTest is BaseTest {
    function test_CreateAcceptReveal_3Rounds_WinnerPaid() public {
        Types.MatchConfig memory cfg = _defaultConfig(3);

        uint256[] memory aLineup = new uint256[](3);
        aLineup[0] = 1;
        aLineup[1] = 2;
        aLineup[2] = 5;

        uint256[] memory bLineup = new uint256[](3);
        bLineup[0] = 3;
        bLineup[1] = 4;
        bLineup[2] = 2;

        uint256 matchId = game.nextMatchId();
        bytes32 aSalt = keccak256("a");
        bytes32 bSalt = keccak256("b");

        bytes32 aCommit = _commit(matchId, alice, aLineup, aSalt);
        bytes32 bCommit = _commit(matchId, bob, bLineup, bSalt);

        uint256 totalBefore = token.balanceOf(alice) + token.balanceOf(bob) + token.balanceOf(address(game));

        vm.prank(alice);
        game.createChallenge(cfg, aCommit);

        vm.prank(bob);
        game.acceptChallenge(matchId, bCommit);

        vm.prank(alice);
        game.reveal(matchId, aLineup, aSalt);

        vm.prank(bob);
        game.reveal(matchId, bLineup, bSalt);

        (, Types.MatchState state,,,,,) = game.getMatchInfo(matchId);
        assertEq(uint8(state), uint8(Types.MatchState.Resolved));
        assertEq(token.balanceOf(address(game)), 0, "no dust left in game");
        uint256 totalAfter = token.balanceOf(alice) + token.balanceOf(bob) + token.balanceOf(address(game));
        assertEq(totalAfter, totalBefore, "token conservation");
    }

    function test_DrawRefund_SameLineups() public {
        Types.MatchConfig memory cfg = _defaultConfig(3);

        uint256[] memory lineup = new uint256[](3);
        lineup[0] = 1;
        lineup[1] = 2;
        lineup[2] = 3;

        uint256 matchId = game.nextMatchId();
        bytes32 aSalt = keccak256("a");
        bytes32 bSalt = keccak256("b");
        bytes32 aCommit = _commit(matchId, alice, lineup, aSalt);
        bytes32 bCommit = _commit(matchId, bob, lineup, bSalt);

        uint256 aliceBefore = token.balanceOf(alice);
        uint256 bobBefore = token.balanceOf(bob);

        vm.prank(alice);
        game.createChallenge(cfg, aCommit);
        vm.prank(bob);
        game.acceptChallenge(matchId, bCommit);

        vm.prank(alice);
        game.reveal(matchId, lineup, aSalt);
        vm.prank(bob);
        game.reveal(matchId, lineup, bSalt);

        assertEq(token.balanceOf(alice), aliceBefore);
        assertEq(token.balanceOf(bob), bobBefore);
    }

    function test_Rounds_6_And_9() public {
        registry.createCardType(6, ICardRegistry.CardStats({combat: 7, defense: 5, speed: 7, element: 0, exists: false}));
        registry.createCardType(7, ICardRegistry.CardStats({combat: 6, defense: 6, speed: 7, element: 0, exists: false}));
        registry.createCardType(8, ICardRegistry.CardStats({combat: 6, defense: 7, speed: 6, element: 0, exists: false}));
        registry.createCardType(9, ICardRegistry.CardStats({combat: 7, defense: 6, speed: 6, element: 0, exists: false}));
        registry.createCardType(10, ICardRegistry.CardStats({combat: 6, defense: 6, speed: 8, element: 0, exists: false}));

        for (uint8 rounds = 6; rounds <= 9; rounds += 3) {
            Types.MatchConfig memory cfg = _defaultConfig(rounds);

            uint256[] memory aLineup = new uint256[](rounds);
            uint256[] memory bLineup = new uint256[](rounds);
            if (rounds == 6) {
                for (uint256 i = 0; i < rounds; i++) {
                    aLineup[i] = i + 1; // 1..6
                    bLineup[i] = i + 5; // 5..10
                }
            } else {
                for (uint256 i = 0; i < rounds; i++) {
                    aLineup[i] = i + 1; // 1..9
                    bLineup[i] = i + 2; // 2..10
                }
            }

            uint256 matchId = game.nextMatchId();
            bytes32 aSalt = keccak256(abi.encode(rounds, "a"));
            bytes32 bSalt = keccak256(abi.encode(rounds, "b"));
            bytes32 aCommit = _commit(matchId, alice, aLineup, aSalt);
            bytes32 bCommit = _commit(matchId, bob, bLineup, bSalt);

            vm.prank(alice);
            game.createChallenge(cfg, aCommit);
            vm.prank(bob);
            game.acceptChallenge(matchId, bCommit);
            vm.prank(alice);
            game.reveal(matchId, aLineup, aSalt);
            vm.prank(bob);
            game.reveal(matchId, bLineup, bSalt);

            (, Types.MatchState state,,,,,) = game.getMatchInfo(matchId);
            assertEq(uint8(state), uint8(Types.MatchState.Resolved));
        }
    }

    function test_RevertAccept_SelfMatch() public {
        Types.MatchConfig memory cfg = _defaultConfig(3);
        uint256[] memory aLineup = new uint256[](3);
        aLineup[0] = 1;
        aLineup[1] = 2;
        aLineup[2] = 3;
        uint256 matchId = game.nextMatchId();
        bytes32 salt = keccak256("a");
        bytes32 commitHash = _commit(matchId, alice, aLineup, salt);
        vm.prank(alice);
        game.createChallenge(cfg, commitHash);
        vm.prank(alice);
        vm.expectRevert(Errors.SelfMatch.selector);
        game.acceptChallenge(matchId, commitHash);
    }
}
