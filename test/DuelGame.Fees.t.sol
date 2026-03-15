// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./Base.t.sol";

import {FeeModule} from "../src/FeeModule.sol";
import {Errors} from "../src/libraries/Errors.sol";
import {Types} from "../src/libraries/Types.sol";

contract DuelGameFeesTest is BaseTest {
    address internal treasury = makeAddr("treasury");
    FeeModule internal module;

    function _createAndAccept(
        Types.MatchConfig memory cfg,
        uint256[] memory aLineup,
        bytes32 aSalt,
        uint256[] memory bLineup,
        bytes32 bSalt
    ) internal returns (uint256 matchId) {
        matchId = game.nextMatchId();
        bytes32 aCommit = _commit(matchId, alice, aLineup, aSalt);
        bytes32 bCommit = _commit(matchId, bob, bLineup, bSalt);

        vm.prank(alice);
        game.createChallenge(cfg, aCommit);
        vm.prank(bob);
        game.acceptChallenge(matchId, bCommit);
    }

    function setUp() public override {
        super.setUp();

        module = new FeeModule(address(this), treasury, 500);
        game.setFeeModule(address(module));
    }

    function test_WinnerPaysFee_TreasuryReceives() public {
        Types.MatchConfig memory cfg = _defaultConfig(3);
        uint256 stake = uint256(cfg.stake);

        uint256[] memory aLineup = new uint256[](3);
        aLineup[0] = 1;
        aLineup[1] = 2;
        aLineup[2] = 5;

        uint256[] memory bLineup = new uint256[](3);
        bLineup[0] = 3;
        bLineup[1] = 4;
        bLineup[2] = 2;

        bytes32 aSalt = keccak256("a");
        bytes32 bSalt = keccak256("b");

        uint256 aliceBefore = token.balanceOf(alice);
        uint256 bobBefore = token.balanceOf(bob);
        uint256 treasuryBefore = token.balanceOf(treasury);

        uint256 matchId = _createAndAccept(cfg, aLineup, aSalt, bLineup, bSalt);
        vm.prank(alice);
        game.reveal(matchId, aLineup, aSalt);
        vm.prank(bob);
        game.reveal(matchId, bLineup, bSalt);

        uint256 pot = stake * 2;
        uint256 fee = (pot * 500) / 10_000;

        assertEq(token.balanceOf(treasury), treasuryBefore + fee);
        assertEq(token.balanceOf(address(game)), 0);

        uint256 aliceAfter = token.balanceOf(alice);
        uint256 bobAfter = token.balanceOf(bob);

        bool aliceWinner = (aliceAfter == aliceBefore + stake - fee) && (bobAfter == bobBefore - stake);
        bool bobWinner = (bobAfter == bobBefore + stake - fee) && (aliceAfter == aliceBefore - stake);
        assertTrue(aliceWinner || bobWinner, "unexpected balances (fee payout)");
    }

    function test_Draw_NoFee() public {
        Types.MatchConfig memory cfg = _defaultConfig(3);

        uint256[] memory lineup = new uint256[](3);
        lineup[0] = 1;
        lineup[1] = 2;
        lineup[2] = 3;

        bytes32 aSalt = keccak256("a");
        bytes32 bSalt = keccak256("b");

        uint256 aliceBefore = token.balanceOf(alice);
        uint256 bobBefore = token.balanceOf(bob);
        uint256 treasuryBefore = token.balanceOf(treasury);

        uint256 matchId = _createAndAccept(cfg, lineup, aSalt, lineup, bSalt);
        vm.prank(alice);
        game.reveal(matchId, lineup, aSalt);
        vm.prank(bob);
        game.reveal(matchId, lineup, bSalt);

        assertEq(token.balanceOf(treasury), treasuryBefore);
        assertEq(token.balanceOf(alice), aliceBefore);
        assertEq(token.balanceOf(bob), bobBefore);
        assertEq(token.balanceOf(address(game)), 0);
    }

    function test_ForfeitWinnerPaysFee() public {
        Types.MatchConfig memory cfg = _defaultConfig(3);
        uint256 stake = uint256(cfg.stake);

        uint256[] memory aLineup = new uint256[](3);
        aLineup[0] = 1;
        aLineup[1] = 2;
        aLineup[2] = 3;

        uint256[] memory bLineup = new uint256[](3);
        bLineup[0] = 3;
        bLineup[1] = 4;
        bLineup[2] = 5;

        bytes32 aSalt = keccak256("a");
        bytes32 bSalt = keccak256("b");

        uint256 aliceBefore = token.balanceOf(alice);
        uint256 bobBefore = token.balanceOf(bob);
        uint256 treasuryBefore = token.balanceOf(treasury);

        uint256 matchId = _createAndAccept(cfg, aLineup, aSalt, bLineup, bSalt);

        vm.prank(alice);
        game.reveal(matchId, aLineup, aSalt);

        (, , , , , , uint64 deadline) = game.getMatchInfo(matchId);
        vm.warp(uint256(deadline) + 1);
        game.claimForfeit(matchId);

        uint256 pot = stake * 2;
        uint256 fee = (pot * 500) / 10_000;

        assertEq(token.balanceOf(treasury), treasuryBefore + fee);
        assertEq(token.balanceOf(alice), aliceBefore + stake - fee);
        assertEq(token.balanceOf(bob), bobBefore - stake);
        assertEq(token.balanceOf(address(game)), 0);
    }

    function test_DisableFeeModule_BehaviorUnchanged() public {
        game.setFeeModule(address(0));

        Types.MatchConfig memory cfg = _defaultConfig(3);
        uint256 stake = uint256(cfg.stake);

        uint256[] memory aLineup = new uint256[](3);
        aLineup[0] = 1;
        aLineup[1] = 2;
        aLineup[2] = 5;

        uint256[] memory bLineup = new uint256[](3);
        bLineup[0] = 3;
        bLineup[1] = 4;
        bLineup[2] = 2;

        bytes32 aSalt = keccak256("a");
        bytes32 bSalt = keccak256("b");

        uint256 aliceBefore = token.balanceOf(alice);
        uint256 bobBefore = token.balanceOf(bob);
        uint256 treasuryBefore = token.balanceOf(treasury);

        uint256 matchId = _createAndAccept(cfg, aLineup, aSalt, bLineup, bSalt);
        vm.prank(alice);
        game.reveal(matchId, aLineup, aSalt);
        vm.prank(bob);
        game.reveal(matchId, bLineup, bSalt);

        assertEq(token.balanceOf(treasury), treasuryBefore);
        assertEq(token.balanceOf(address(game)), 0);

        uint256 aliceAfter = token.balanceOf(alice);
        uint256 bobAfter = token.balanceOf(bob);

        bool aliceWinner = (aliceAfter == aliceBefore + stake) && (bobAfter == bobBefore - stake);
        bool bobWinner = (bobAfter == bobBefore + stake) && (aliceAfter == aliceBefore - stake);
        assertTrue(aliceWinner || bobWinner, "unexpected balances (no-fee payout)");
    }

    function test_SetFeeModule_OnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        game.setFeeModule(address(module));
    }

    function test_FeeModule_SetTreasury_OnlyOwner_AndNonZero() public {
        vm.prank(alice);
        vm.expectRevert();
        module.setTreasury(makeAddr("x"));

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidTreasury.selector, address(0)));
        module.setTreasury(address(0));
    }

    function test_FeeModule_SetFeeBps_OnlyOwner_AndMax() public {
        vm.prank(alice);
        vm.expectRevert();
        module.setFeeBps(100);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidFeeBps.selector, uint16(501)));
        module.setFeeBps(501);
    }
}
