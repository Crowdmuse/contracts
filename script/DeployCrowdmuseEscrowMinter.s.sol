// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {CrowdmuseEscrowMinter} from "../src/minters/CrowdmuseEscrowMinter.sol";

/// @title Deploy script for CrowdmuseEscrowMinter
contract DeployCrowdmuseEscrowMinter is Script {
    function run() external {
        vm.startBroadcast();

        CrowdmuseEscrowMinter minter = new CrowdmuseEscrowMinter();

        console.log("CrowdmuseEscrowMinter deployed to:", address(minter));

        vm.stopBroadcast();
    }
}
