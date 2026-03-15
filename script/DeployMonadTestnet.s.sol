// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {CardRegistry} from "../src/CardRegistry.sol";
import {DuelGame} from "../src/DuelGame.sol";
import {FeeModule} from "../src/FeeModule.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {ICardRegistry} from "../src/interfaces/ICardRegistry.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployMonadTestnet is Script {
    function run()
        external
        returns (IERC20 stakeToken, CardRegistry registry, DuelGame game, FeeModule feeModule)
    {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        uint16 feeBpsDefault = uint16(vm.envOr("FEE_BPS_DEFAULT", uint256(200)));
        address stakeTokenAddr = vm.envOr("STAKE_TOKEN", address(0));
        address mintTo1 = vm.envOr("MINT_TO_1", deployer);
        address mintTo2 = vm.envOr("MINT_TO_2", address(0));
        uint256 mintAmount = vm.envOr("MINT_AMOUNT", uint256(10e18));

        vm.startBroadcast(deployerKey);

        if (stakeTokenAddr == address(0)) {
            MockERC20 token = new MockERC20("Duel USD", "DUSD");
            stakeToken = IERC20(address(token));

            if (mintTo1 == address(0)) mintTo1 = deployer;
            token.mint(mintTo1, mintAmount);
            if (mintTo2 != address(0) && mintTo2 != mintTo1) {
                token.mint(mintTo2, mintAmount);
            }
        } else {
            stakeToken = IERC20(stakeTokenAddr);
        }

        registry = new CardRegistry(deployer);
        feeModule = new FeeModule(deployer, deployer, feeBpsDefault);
        game = new DuelGame(stakeToken, registry, deployer, 1 days);
        game.setFeeModule(address(feeModule));

        _registerInitialCards(registry);

        vm.stopBroadcast();
    }

    function _registerInitialCards(CardRegistry registry) internal {
        registry.createCardType(1, ICardRegistry.CardStats({combat: 7, defense: 6, speed: 6, element: 0, exists: false}));
        registry.createCardType(2, ICardRegistry.CardStats({combat: 6, defense: 7, speed: 6, element: 0, exists: false}));
        registry.createCardType(3, ICardRegistry.CardStats({combat: 6, defense: 6, speed: 7, element: 0, exists: false}));

        registry.createCardType(4, ICardRegistry.CardStats({combat: 8, defense: 5, speed: 6, element: 1, exists: false}));
        registry.createCardType(5, ICardRegistry.CardStats({combat: 7, defense: 6, speed: 6, element: 1, exists: false}));
        registry.createCardType(6, ICardRegistry.CardStats({combat: 7, defense: 5, speed: 7, element: 1, exists: false}));

        registry.createCardType(7, ICardRegistry.CardStats({combat: 7, defense: 6, speed: 6, element: 2, exists: false}));
        registry.createCardType(8, ICardRegistry.CardStats({combat: 6, defense: 7, speed: 6, element: 2, exists: false}));
        registry.createCardType(9, ICardRegistry.CardStats({combat: 6, defense: 6, speed: 7, element: 2, exists: false}));

        registry.createCardType(10, ICardRegistry.CardStats({combat: 6, defense: 7, speed: 6, element: 3, exists: false}));
        registry.createCardType(11, ICardRegistry.CardStats({combat: 7, defense: 6, speed: 6, element: 3, exists: false}));
        registry.createCardType(12, ICardRegistry.CardStats({combat: 6, defense: 6, speed: 7, element: 3, exists: false}));

        registry.createCardType(13, ICardRegistry.CardStats({combat: 6, defense: 5, speed: 9, element: 4, exists: false}));
        registry.createCardType(14, ICardRegistry.CardStats({combat: 7, defense: 5, speed: 7, element: 4, exists: false}));
        registry.createCardType(15, ICardRegistry.CardStats({combat: 6, defense: 6, speed: 7, element: 4, exists: false}));

        registry.createCardType(16, ICardRegistry.CardStats({combat: 6, defense: 8, speed: 5, element: 5, exists: false}));
        registry.createCardType(17, ICardRegistry.CardStats({combat: 7, defense: 7, speed: 4, element: 5, exists: false}));
        registry.createCardType(18, ICardRegistry.CardStats({combat: 6, defense: 7, speed: 6, element: 5, exists: false}));
    }

}
