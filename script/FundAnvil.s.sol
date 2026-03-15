// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {MockERC20} from "../src/mocks/MockERC20.sol";

contract FundAnvil is Script {
    // Anvil default account #0 private key (for the default mnemonic).
    uint256 internal constant DEFAULT_ANVIL_PK =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() external {
        uint256 funderKey = vm.envOr("PRIVATE_KEY", DEFAULT_ANVIL_PK);

        address recipient = vm.envAddress("RECIPIENT");
        address token = vm.envAddress("TOKEN");

        uint256 ethAmountWei = vm.envOr("ETH_AMOUNT_WEI", uint256(1 ether));
        uint256 tokenAmount = vm.envOr("TOKEN_AMOUNT", uint256(1_000_000e18));

        vm.startBroadcast(funderKey);

        // Fund ETH
        (bool ok,) = payable(recipient).call{value: ethAmountWei}("");
        require(ok, "ETH_TRANSFER_FAILED");

        // Mint MockERC20 to recipient
        MockERC20(token).mint(recipient, tokenAmount);

        vm.stopBroadcast();
    }
}

