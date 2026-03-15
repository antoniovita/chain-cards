// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {BattleLib} from "../src/libraries/BattleLib.sol";
import {Types} from "../src/libraries/Types.sol";
import {ICardRegistry} from "../src/interfaces/ICardRegistry.sol";

contract DuelGameBattleTest is Test {
    function _cfg(bool useElement, bool useTotal, uint16 mult) private pure returns (Types.MatchConfig memory) {
        return Types.MatchConfig({
            stake: 1,
            rounds: 3,
            elementalMultiplierBps: mult,
            useElementAdvantage: useElement,
            useTotalStatsTiebreaker: useTotal
        });
    }

    function test_Round_ElementalMultiplier_AppliesToStrongSide() public pure {
        ICardRegistry.CardStats memory a =
            ICardRegistry.CardStats({combat: 10, defense: 1, speed: 1, element: 1, exists: true}); // Fire
        ICardRegistry.CardStats memory b =
            ICardRegistry.CardStats({combat: 10, defense: 1, speed: 1, element: 3, exists: true}); // Grass

        Types.MatchConfig memory cfg = _cfg(true, false, 12_500);
        BattleLib.RoundOutcome memory out =
            BattleLib.resolveRound(a, b, BattleLib.Attribute.Combat, int8(1), cfg); // A strong

        assertEq(out.valueA, 12);
        assertEq(out.valueB, 10);
        assertEq(out.winner, 1);
    }

    function test_Tiebreak_ElementAdvantage_WhenAdjustedTie() public pure {
        ICardRegistry.CardStats memory a =
            ICardRegistry.CardStats({combat: 10, defense: 5, speed: 5, element: 1, exists: true}); // Fire
        ICardRegistry.CardStats memory b =
            ICardRegistry.CardStats({combat: 10, defense: 5, speed: 5, element: 3, exists: true}); // Grass

        Types.MatchConfig memory cfg = _cfg(true, false, 10_000); // multiplier no-op
        BattleLib.RoundOutcome memory out =
            BattleLib.resolveRound(a, b, BattleLib.Attribute.Combat, int8(1), cfg); // A strong

        assertEq(out.valueA, 10);
        assertEq(out.valueB, 10);
        assertEq(out.winner, 1);
    }

    function test_Tiebreak_TotalStats() public pure {
        ICardRegistry.CardStats memory a =
            ICardRegistry.CardStats({combat: 10, defense: 4, speed: 4, element: 0, exists: true}); // total 18
        ICardRegistry.CardStats memory b =
            ICardRegistry.CardStats({combat: 10, defense: 3, speed: 3, element: 0, exists: true}); // total 16

        Types.MatchConfig memory cfg = _cfg(false, true, 10_000);
        BattleLib.RoundOutcome memory out =
            BattleLib.resolveRound(a, b, BattleLib.Attribute.Combat, int8(0), cfg);

        assertEq(out.winner, 1);
    }

    function test_Tiebreak_SecondaryAttributes_OrderByRoundAttribute() public pure {
        // Primary: Combat ties. Total ties. Secondary order: Defense then Speed.
        ICardRegistry.CardStats memory a =
            ICardRegistry.CardStats({combat: 10, defense: 6, speed: 4, element: 0, exists: true}); // total 20
        ICardRegistry.CardStats memory b =
            ICardRegistry.CardStats({combat: 10, defense: 5, speed: 5, element: 0, exists: true}); // total 20

        Types.MatchConfig memory cfg = _cfg(false, true, 10_000);
        BattleLib.RoundOutcome memory out =
            BattleLib.resolveRound(a, b, BattleLib.Attribute.Combat, int8(0), cfg);

        assertEq(out.winner, 1);
    }

    function test_Tiebreak_SecondaryAttributes_DefenseRound_Order() public pure {
        // Primary: Defense ties. Total ties. Secondary order: Speed then Combat.
        ICardRegistry.CardStats memory a =
            ICardRegistry.CardStats({combat: 6, defense: 10, speed: 4, element: 0, exists: true}); // total 20
        ICardRegistry.CardStats memory b =
            ICardRegistry.CardStats({combat: 5, defense: 10, speed: 5, element: 0, exists: true}); // total 20

        Types.MatchConfig memory cfg = _cfg(false, true, 10_000);
        BattleLib.RoundOutcome memory out =
            BattleLib.resolveRound(a, b, BattleLib.Attribute.Defense, int8(0), cfg);

        assertEq(out.winner, -1);
    }
}

