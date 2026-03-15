// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {CardRegistry} from "../src/CardRegistry.sol";
import {ICardRegistry} from "../src/interfaces/ICardRegistry.sol";
import {Errors} from "../src/libraries/Errors.sol";

contract CardRegistryTest is Test {
    CardRegistry internal registry;

    function setUp() public {
        registry = new CardRegistry(address(this));
    }

    function test_CreateAndGetCard() public {
        registry.createCardType(1, ICardRegistry.CardStats({combat: 7, defense: 7, speed: 6, element: 1, exists: false}));
        ICardRegistry.CardStats memory s = registry.getCardStats(1);
        assertTrue(s.exists);
        assertEq(s.combat, 7);
        assertEq(s.defense, 7);
        assertEq(s.speed, 6);
        assertEq(s.element, 1);
        assertTrue(registry.cardExists(1));
    }

    function test_RevertCreateCard_ZeroId() public {
        vm.expectRevert(Errors.ZeroCardId.selector);
        registry.createCardType(0, ICardRegistry.CardStats({combat: 1, defense: 1, speed: 1, element: 0, exists: false}));
    }

    function test_RevertCreateCard_InvalidElement() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidElement.selector, uint8(6)));
        registry.createCardType(1, ICardRegistry.CardStats({combat: 1, defense: 1, speed: 1, element: 6, exists: false}));
    }

    function test_RevertCreateCard_Duplicate() public {
        registry.createCardType(1, ICardRegistry.CardStats({combat: 1, defense: 1, speed: 1, element: 0, exists: false}));
        vm.expectRevert(abi.encodeWithSelector(Errors.CardAlreadyExists.selector, uint256(1)));
        registry.createCardType(1, ICardRegistry.CardStats({combat: 2, defense: 2, speed: 2, element: 0, exists: false}));
    }

    function test_RevertGetCard_NotFound() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.CardNotFound.selector, uint256(1)));
        registry.getCardStats(1);
    }

    function test_RevertCreateCard_NotOwner() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert();
        registry.createCardType(1, ICardRegistry.CardStats({combat: 1, defense: 1, speed: 1, element: 0, exists: false}));
    }
}

