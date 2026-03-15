// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICardRegistry} from "../interfaces/ICardRegistry.sol";
import {Types} from "./Types.sol";

library BattleLib {
    enum Attribute {
        Combat,
        Defense,
        Speed
    }

    struct RoundOutcome {
        int8 winner; // 1 = A, -1 = B, 0 = draw
        Attribute attribute;
        uint256 valueA;
        uint256 valueB;
        int8 elementalOutcome; // 1 = A strong, -1 = B strong, 0 = neutral
    }

    function attributeForRound(uint8 roundIndex0) internal pure returns (Attribute) {
        return Attribute(roundIndex0 % 3);
    }

    function resolveRound(
        ICardRegistry.CardStats memory a,
        ICardRegistry.CardStats memory b,
        Attribute attribute,
        int8 elementalOutcome,
        Types.MatchConfig memory config
    ) internal pure returns (RoundOutcome memory out) {
        uint16 baseA = _valueForAttribute(a, attribute);
        uint16 baseB = _valueForAttribute(b, attribute);

        uint256 adjustedA = baseA;
        uint256 adjustedB = baseB;

        if (config.useElementAdvantage && elementalOutcome != 0) {
            uint256 m = uint256(config.elementalMultiplierBps);
            if (elementalOutcome > 0) {
                adjustedA = (uint256(baseA) * m) / 10_000;
            } else {
                adjustedB = (uint256(baseB) * m) / 10_000;
            }
        }

        int8 winner = _compare(adjustedA, adjustedB);

        if (winner == 0) {
            winner = _tiebreak(a, b, attribute, elementalOutcome, config);
        }

        out = RoundOutcome({
            winner: winner,
            attribute: attribute,
            valueA: adjustedA,
            valueB: adjustedB,
            elementalOutcome: config.useElementAdvantage ? elementalOutcome : int8(0)
        });
    }

    function roundWinner(
        ICardRegistry.CardStats memory a,
        ICardRegistry.CardStats memory b,
        Attribute attribute,
        int8 elementalOutcome,
        Types.MatchConfig memory config
    ) internal pure returns (int8) {
        uint16 baseA = _valueForAttribute(a, attribute);
        uint16 baseB = _valueForAttribute(b, attribute);

        uint256 adjustedA = baseA;
        uint256 adjustedB = baseB;

        if (config.useElementAdvantage && elementalOutcome != 0) {
            uint256 m = uint256(config.elementalMultiplierBps);
            if (elementalOutcome > 0) {
                adjustedA = (uint256(baseA) * m) / 10_000;
            } else {
                adjustedB = (uint256(baseB) * m) / 10_000;
            }
        }

        int8 winner = _compare(adjustedA, adjustedB);
        if (winner == 0) {
            winner = _tiebreak(a, b, attribute, elementalOutcome, config);
        }
        return winner;
    }

    function _tiebreak(
        ICardRegistry.CardStats memory a,
        ICardRegistry.CardStats memory b,
        Attribute attribute,
        int8 elementalOutcome,
        Types.MatchConfig memory config
    ) private pure returns (int8) {
        if (config.useElementAdvantage && elementalOutcome != 0) {
            return elementalOutcome > 0 ? int8(1) : int8(-1);
        }

        if (config.useTotalStatsTiebreaker) {
            uint16 totalA = a.combat + a.defense + a.speed;
            uint16 totalB = b.combat + b.defense + b.speed;
            int8 byTotal = _compare(totalA, totalB);
            if (byTotal != 0) return byTotal;
        }

        (Attribute first, Attribute second) = _secondaryOrder(attribute);

        int8 byFirst = _compare(_valueForAttribute(a, first), _valueForAttribute(b, first));
        if (byFirst != 0) return byFirst;

        int8 bySecond = _compare(_valueForAttribute(a, second), _valueForAttribute(b, second));
        if (bySecond != 0) return bySecond;

        return 0;
    }

    function _secondaryOrder(Attribute attribute) private pure returns (Attribute first, Attribute second) {
        if (attribute == Attribute.Combat) return (Attribute.Defense, Attribute.Speed);
        if (attribute == Attribute.Defense) return (Attribute.Speed, Attribute.Combat);
        return (Attribute.Combat, Attribute.Defense);
    }

    function _valueForAttribute(ICardRegistry.CardStats memory s, Attribute attribute) private pure returns (uint16) {
        if (attribute == Attribute.Combat) return s.combat;
        if (attribute == Attribute.Defense) return s.defense;
        return s.speed;
    }

    function _compare(uint256 x, uint256 y) private pure returns (int8) {
        if (x > y) return 1;
        if (x < y) return -1;
        return 0;
    }
}
