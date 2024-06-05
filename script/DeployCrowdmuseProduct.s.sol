// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/CrowdmuseProduct.sol";
import "../src/interfaces/ICrowdmuseProduct.sol";

contract DeployCrowdmuseProduct is Script {
    function run() external {
        vm.startBroadcast();

        uint256[] memory contributionValues = new uint256[](1);
        contributionValues[0] = 1000;
        address[] memory taskContributors = new address[](1);
        taskContributors[0] = 0x35CE1fb8CAa3758190ac65EDbcBC9647b8800e8f;
        ICrowdmuseProduct.TaskStatus[]
            memory taskStatuses = new ICrowdmuseProduct.TaskStatus[](1);
        taskStatuses[0] = ICrowdmuseProduct.TaskStatus.Complete;
        uint256[] memory taskContributorTypes = new uint256[](1);
        taskContributorTypes[0] = 1;
        ICrowdmuseProduct.Task memory task = ICrowdmuseProduct.Task({
            contributionValues: contributionValues,
            taskContributors: taskContributors,
            taskStatus: taskStatuses,
            taskContributorTypes: taskContributorTypes
        });
        ICrowdmuseProduct.Token memory token = ICrowdmuseProduct.Token({
            productName: "crowdmuse-product",
            productSymbol: "CMUSE",
            baseUri: "ipfs://cid",
            maxAmountOfTokensPerMint: type(uint256).max
        });
        uint96 feeNumerator = 500;
        uint96 contributorTotalSupply = 10000;
        uint96 garmentsAvailable = type(uint96).max;
        string memory inventoryKeyName = "crowdmuse-product-inventory-key";

        ICrowdmuseProduct.Inventory[]
            memory inventory = new ICrowdmuseProduct.Inventory[](1);
        inventory[0] = ICrowdmuseProduct.Inventory({
            keyName: "size:one",
            garmentsRemaining: garmentsAvailable
        });
        address usdc_base_sepolia = 0x63148156DACb0e8555287906F8FC229E0b11365b;
        address paymentTokenAddress = usdc_base_sepolia;
        bool madeToOrder = false;
        address admin = 0x35CE1fb8CAa3758190ac65EDbcBC9647b8800e8f;
        uint256 buyNFTPrice = 1 ether;
        CrowdmuseProduct product = new CrowdmuseProduct(
            feeNumerator,
            contributorTotalSupply,
            garmentsAvailable,
            task,
            token,
            paymentTokenAddress,
            inventoryKeyName,
            inventory,
            madeToOrder,
            admin,
            buyNFTPrice
        );

        console.log("CrowdmuseProduct deployed to:", address(product));

        vm.stopBroadcast();
    }
}
