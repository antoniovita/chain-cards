// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {CardRegistry} from "../src/CardRegistry.sol";
import {DuelGame} from "../src/DuelGame.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {ICardRegistry} from "../src/interfaces/ICardRegistry.sol";
import {Types} from "../src/libraries/Types.sol";

abstract contract BaseTest is Test {
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    MockERC20 internal token;
    CardRegistry internal registry;
    DuelGame internal game;

    function setUp() public virtual {
        token = new MockERC20("Mock", "MOCK");
        registry = new CardRegistry(address(this));
        game = new DuelGame(token, registry, address(this), 1 days);

        _registerInitialCards();

        token.mint(alice, 1_000_000e18);
        token.mint(bob, 1_000_000e18);
        token.mint(carol, 1_000_000e18);

        vm.prank(alice);
        token.approve(address(game), type(uint256).max);
        vm.prank(bob);
        token.approve(address(game), type(uint256).max);
        vm.prank(carol);
        token.approve(address(game), type(uint256).max);
    }

    function _registerInitialCards() internal {
        registry.createCardType(1, ICardRegistry.CardStats({combat: 8, defense: 5, speed: 6, element: 1, exists: false})); // Fire
        registry.createCardType(2, ICardRegistry.CardStats({combat: 7, defense: 6, speed: 6, element: 2, exists: false})); // Water
        registry.createCardType(3, ICardRegistry.CardStats({combat: 6, defense: 7, speed: 6, element: 3, exists: false})); // Grass
        registry.createCardType(4, ICardRegistry.CardStats({combat: 6, defense: 8, speed: 5, element: 5, exists: false})); // Rock
        registry.createCardType(5, ICardRegistry.CardStats({combat: 6, defense: 5, speed: 9, element: 4, exists: false})); // Electric
    }

    function _defaultConfig(uint8 rounds) internal pure returns (Types.MatchConfig memory) {
        return Types.MatchConfig({
            stake: 100e18,
            rounds: rounds,
            elementalMultiplierBps: 12_500,
            useElementAdvantage: true,
            useTotalStatsTiebreaker: true
        });
    }

    function _commit(uint256 matchId, address player, uint256[] memory lineup, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(matchId, player, lineup, salt));
    }
}

