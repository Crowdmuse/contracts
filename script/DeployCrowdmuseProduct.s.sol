// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/CrowdmuseProduct.sol";
import "../src/interfaces/ICrowdmuseProduct.sol";

contract DeployCrowdmuseProduct is Script, ICrowdmuseProduct {
    function run() external {
        vm.startBroadcast();

        uint256[] memory contributionValues = new uint256[](1);
        contributionValues[0] = 1000;
        address[] memory taskContributors = new address[](1);
        taskContributors[0] = 0x35CE1fb8CAa3758190ac65EDbcBC9647b8800e8f;
        TaskStatus[] memory taskStatuses = new TaskStatus[](1);
        taskStatuses[0] = TaskStatus.Complete;
        uint256[] memory taskContributorTypes = new uint256[](1);
        taskContributorTypes[0] = 1;
        Task memory task = Task({
            contributionValues: contributionValues,
            taskContributors: taskContributors,
            taskStatus: taskStatuses,
            taskContributorTypes: taskContributorTypes
        });
        Token memory token = Token({
            productName: "MyProduct",
            productSymbol: "MPROD",
            baseUri: "ipfs://baseuri/",
            maxAmountOfTokensPerMint: 10
        });
        uint96 feeNumerator = 500;
        uint96 contributorTotalSupply = 10000;
        uint96 garmentsAvailable = 100;

        Inventory[] memory inventory = new Inventory[](1);
        inventory[0] = Inventory({keyName: "size:one", garmentsRemaining: 100});
        address usdc_base_sepolia = 0x63148156DACb0e8555287906F8FC229E0b11365b;
        CrowdmuseProduct product = new CrowdmuseProduct(
            feeNumerator,
            contributorTotalSupply,
            garmentsAvailable,
            task,
            token,
            usdc_base_sepolia,
            "InventoryKey",
            inventory,
            false, // _madeToOrder
            0x35CE1fb8CAa3758190ac65EDbcBC9647b8800e8f,
            1 ether // _buyNFTPrice
        );

        console.log("CrowdmuseProduct deployed to:", address(product));

        vm.stopBroadcast(); // Stop broadcasting transactions
    }
}
