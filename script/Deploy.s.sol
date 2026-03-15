// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {CardRegistry} from "../src/CardRegistry.sol";
import {DuelGame} from "../src/DuelGame.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {ICardRegistry} from "../src/interfaces/ICardRegistry.sol";

contract Deploy is Script {
    function run() external returns (MockERC20 token, CardRegistry registry, DuelGame game) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        token = new MockERC20("Duel USD", "DUSD");
        registry = new CardRegistry(deployer);
        game = new DuelGame(token, registry, deployer, 1 days);

        _registerInitialCards(registry);

        vm.stopBroadcast();
    }

    function _registerInitialCards(CardRegistry registry) internal {
        registry.createCardType(1, ICardRegistry.CardStats({combat: 8, defense: 5, speed: 6, element: 1, exists: false})); // Flame Tiger (Fire)
        registry.createCardType(2, ICardRegistry.CardStats({combat: 7, defense: 6, speed: 6, element: 2, exists: false})); // Aqua Serpent (Water)
        registry.createCardType(3, ICardRegistry.CardStats({combat: 6, defense: 7, speed: 6, element: 3, exists: false})); // Plant Beast (Grass)
        registry.createCardType(4, ICardRegistry.CardStats({combat: 6, defense: 8, speed: 5, element: 5, exists: false})); // Rock Golem (Rock)
        registry.createCardType(5, ICardRegistry.CardStats({combat: 6, defense: 5, speed: 9, element: 4, exists: false})); // Storm Hawk (Electric)
    }
}

