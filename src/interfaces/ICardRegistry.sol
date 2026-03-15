// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICardRegistry {
    struct CardStats {
        uint16 combat;
        uint16 defense;
        uint16 speed;
        uint8 element;
        bool exists;
    }

    function createCardType(uint256 cardId, CardStats calldata stats) external;
    function getCardStats(uint256 cardId) external view returns (CardStats memory);
    function cardExists(uint256 cardId) external view returns (bool);
}

