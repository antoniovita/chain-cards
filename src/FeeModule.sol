// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Errors} from "./libraries/Errors.sol";
import {IFeeModule} from "./interfaces/IFeeModule.sol";

contract FeeModule is IFeeModule, Ownable {
    uint16 public constant MAX_FEE_BPS = 500; // 5%

    address public treasury;
    uint16 public feeBps;

    event TreasurySet(address indexed treasury);
    event FeeBpsSet(uint16 feeBps);

    constructor(address initialOwner, address treasury_, uint16 feeBps_) Ownable(initialOwner) {
        _setTreasury(treasury_);
        _setFeeBps(feeBps_);
    }

    function maxFeeBps() external pure returns (uint16) {
        return MAX_FEE_BPS;
    }

    function setTreasury(address treasury_) external onlyOwner {
        _setTreasury(treasury_);
    }

    function setFeeBps(uint16 feeBps_) external onlyOwner {
        _setFeeBps(feeBps_);
    }

    function computeFee(uint256 pot) external view returns (uint256 fee, uint256 payout) {
        uint16 bps = feeBps;
        if (bps == 0 || pot == 0) return (0, pot);
        fee = (pot * uint256(bps)) / 10_000;
        payout = pot - fee;
    }

    function _setTreasury(address treasury_) internal {
        if (treasury_ == address(0)) revert Errors.InvalidTreasury(treasury_);
        treasury = treasury_;
        emit TreasurySet(treasury_);
    }

    function _setFeeBps(uint16 feeBps_) internal {
        if (feeBps_ > MAX_FEE_BPS) revert Errors.InvalidFeeBps(feeBps_);
        feeBps = feeBps_;
        emit FeeBpsSet(feeBps_);
    }
}

