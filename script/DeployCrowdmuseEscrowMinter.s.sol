// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {CrowdmuseEscrowMinter} from "../src/minters/CrowdmuseEscrowMinter.sol";

/// @title Deploy script for CrowdmuseEscrowMinter
contract DeployCrowdmuseEscrowMinter is Script {
    function run() external {
        vm.startBroadcast();
        address PUSH_SPLIT_FACTORY = 0xaDC87646f736d6A82e9a6539cddC488b2aA07f38;
        CrowdmuseEscrowMinter minter = new CrowdmuseEscrowMinter(
            PUSH_SPLIT_FACTORY
        );

        console.log("CrowdmuseEscrowMinter deployed to:", address(minter));

        vm.stopBroadcast();
    }
}
