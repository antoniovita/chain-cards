// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library CommitLib {
    function computeCommit(
        uint256 matchId,
        address player,
        uint256[] calldata lineup,
        bytes32 salt
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(matchId, player, lineup, salt));
    }
}

