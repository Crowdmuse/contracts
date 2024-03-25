// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {CrowdmuseBasicMinter} from "../src/minters/CrowdmuseBasicMinter.sol";

/// @title Deploy script for CrowdmuseBasicMinter
contract DeployCrowdmuseBasicMinter is Script {
    function run() external {
        vm.startBroadcast();

        CrowdmuseBasicMinter minter = new CrowdmuseBasicMinter();

        console.log("CrowdmuseProduct deployed to:", address(minter));

        vm.stopBroadcast();
    }
}
