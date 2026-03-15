// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ICardRegistry} from "./interfaces/ICardRegistry.sol";
import {Errors} from "./libraries/Errors.sol";

contract CardRegistry is ICardRegistry, Ownable {
    mapping(uint256 => CardStats) private _cards;

    event CardTypeCreated(uint256 indexed cardId, uint16 combat, uint16 defense, uint16 speed, uint8 element);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function createCardType(uint256 cardId, CardStats calldata stats) external onlyOwner {
        if (cardId == 0) revert Errors.ZeroCardId();
        if (_cards[cardId].exists) revert Errors.CardAlreadyExists(cardId);
        if (stats.exists) revert Errors.InvalidCardStats();
        if (stats.element >= 6) revert Errors.InvalidElement(stats.element);

        CardStats memory stored = CardStats({
            combat: stats.combat,
            defense: stats.defense,
            speed: stats.speed,
            element: stats.element,
            exists: true
        });

        _cards[cardId] = stored;
        emit CardTypeCreated(cardId, stored.combat, stored.defense, stored.speed, stored.element);
    }

    function getCardStats(uint256 cardId) external view returns (CardStats memory) {
        CardStats memory stats = _cards[cardId];
        if (!stats.exists) revert Errors.CardNotFound(cardId);
        return stats;
    }

    function cardExists(uint256 cardId) external view returns (bool) {
        return _cards[cardId].exists;
    }
}
