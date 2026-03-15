// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IFeeModule {
    function treasury() external view returns (address);
    function feeBps() external view returns (uint16);
    function maxFeeBps() external view returns (uint16);

    function computeFee(uint256 pot) external view returns (uint256 fee, uint256 payout);
}

