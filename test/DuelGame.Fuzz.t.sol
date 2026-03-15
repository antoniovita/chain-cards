// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./Base.t.sol";
import {Types} from "../src/libraries/Types.sol";
import {ICardRegistry} from "../src/interfaces/ICardRegistry.sol";

contract DuelGameFuzzTest is BaseTest {
    uint256 internal constant CARD_COUNT = 30;

    function setUp() public override {
        super.setUp();

        for (uint256 id = 6; id <= CARD_COUNT; id++) {
            uint16 combat = uint16(6 + (id % 4)); // 6..9
            uint16 defense = uint16(5 + ((id + 1) % 4)); // 5..8
            uint16 speed = uint16(5 + ((id + 2) % 4)); // 5..8
            uint8 element = uint8(id % 6);
            registry.createCardType(id, ICardRegistry.CardStats({combat: combat, defense: defense, speed: speed, element: element, exists: false}));
        }
    }

    function testFuzz_MatchResolves_ConservesBalances(
        uint256 a0,
        uint256 a1,
        uint256 a2,
        uint256 b0,
        uint256 b1,
        uint256 b2,
        bytes32 saltA,
        bytes32 saltB
    ) public {
        Types.MatchConfig memory cfg = _defaultConfig(3);

        uint256[] memory lineupA = new uint256[](3);
        uint256[] memory lineupB = new uint256[](3);

        lineupA[0] = 1 + (a0 % CARD_COUNT);
        lineupA[1] = 1 + (a1 % CARD_COUNT);
        lineupA[2] = 1 + (a2 % CARD_COUNT);
        _makeUnique3(lineupA);

        lineupB[0] = 1 + (b0 % CARD_COUNT);
        lineupB[1] = 1 + (b1 % CARD_COUNT);
        lineupB[2] = 1 + (b2 % CARD_COUNT);
        _makeUnique3(lineupB);

        uint256 matchId = game.nextMatchId();
        bytes32 aCommit = _commit(matchId, alice, lineupA, saltA);
        bytes32 bCommit = _commit(matchId, bob, lineupB, saltB);

        uint256 totalBefore = token.balanceOf(alice) + token.balanceOf(bob) + token.balanceOf(address(game));

        vm.prank(alice);
        game.createChallenge(cfg, aCommit);
        vm.prank(bob);
        game.acceptChallenge(matchId, bCommit);
        vm.prank(alice);
        game.reveal(matchId, lineupA, saltA);
        vm.prank(bob);
        game.reveal(matchId, lineupB, saltB);

        uint256 totalAfter = token.balanceOf(alice) + token.balanceOf(bob) + token.balanceOf(address(game));
        assertEq(totalAfter, totalBefore, "token conservation (alice+bob+game)");
        assertEq(token.balanceOf(address(game)), 0, "no dust left in game");
    }

    function _makeUnique3(uint256[] memory xs) private pure {
        if (xs[1] == xs[0]) {
            xs[1] = (xs[1] % CARD_COUNT) + 1;
            if (xs[1] == xs[0]) xs[1] = (xs[1] % CARD_COUNT) + 1;
        }

        if (xs[2] == xs[0] || xs[2] == xs[1]) {
            xs[2] = (xs[2] % CARD_COUNT) + 1;
            if (xs[2] == xs[0] || xs[2] == xs[1]) xs[2] = ((xs[2] + 1) % CARD_COUNT) + 1;
        }
    }
}
