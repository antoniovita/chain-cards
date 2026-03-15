// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Types {
    enum Element {
        Ice,
        Fire,
        Water,
        Grass,
        Electric,
        Rock
    }

    enum MatchState {
        None,
        Open,
        WaitingReveal,
        Resolved,
        Cancelled
    }

    struct MatchConfig {
        uint96 stake;
        uint8 rounds; // 3,6,9
        uint16 elementalMultiplierBps;
        bool useElementAdvantage;
        bool useTotalStatsTiebreaker;
    }
}

