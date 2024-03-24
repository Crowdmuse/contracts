// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/CrowdmuseProduct.sol"; // Update the path according to your project structure
import "../src/interfaces/ICrowdmuseProduct.sol"; // Update the path according to your project structure

contract DeployCrowdmuseProduct is Script, ICrowdmuseProduct {
    function run() external {
        vm.startBroadcast(); // Start broadcasting transactions

        // Parameters for CrowdmuseProduct constructor
        uint96 feeNumerator = 500;
        uint256 contributorTotalSupply = 10000;
        uint256 garmentsAvailable = 100;

        // Mock task, token, inventory setup goes here
        // These would be replaced with your actual setup
        uint256[] memory contributionValues = new uint256[](1);
        contributionValues[0] = 1000;
        address[] memory taskContributors = new address[](1);
        taskContributors[0] = 0xcfBf34d385EA2d5Eb947063b67eA226dcDA3DC38;
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

        Inventory[] memory inventory = new Inventory[](1);
        inventory[0] = Inventory({keyName: "size:one", garmentsRemaining: 100});
        address paymentTokenAddress = 0xcfBf34d385EA2d5Eb947063b67eA226dcDA3DC38; // Use actual payment token address
        string memory inventoryKey = "InventoryKey";
        bool madeToOrder = false;
        uint256 buyNFTPrice = 1 ether;
        address usdc_base_sepolia = 0x63148156DACb0e8555287906F8FC229E0b11365b;
        CrowdmuseProduct product = new CrowdmuseProduct(
            500, // _feeNumerator
            10000, // _contributorTotalSupply
            100, // _garmentsAvailable
            task,
            token,
            usdc_base_sepolia,
            "InventoryKey",
            inventory,
            false, // _madeToOrder
            0xcfBf34d385EA2d5Eb947063b67eA226dcDA3DC38,
            1 ether // _buyNFTPrice
        );

        console.log("CrowdmuseProduct deployed to:", address(product));

        vm.stopBroadcast(); // Stop broadcasting transactions
    }
}
