// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {CrowdmuseProduct} from "../src/CrowdmuseProduct.sol";
import {ICrowdmuseProduct} from "../src/interfaces/ICrowdmuseProduct.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract CrowdmuseProductTest is Test, ICrowdmuseProduct {
    CrowdmuseProduct public product;
    MockERC20 public usdc;
    address admin;

    function setUp() public {
        admin = address(this); // For simplicity, let the test contract be the admin
        usdc = new MockERC20("MockUSD", "MUSD");

        // Set up initial token, task, and inventory parameters
        Token memory tokenInfo = Token({
            productName: "MyProduct",
            productSymbol: "MPROD",
            baseUri: "ipfs://baseuri/",
            maxAmountOfTokensPerMint: 10
        });

        uint256[] memory contributionValues = new uint256[](1);
        contributionValues[0] = 1000;

        address[] memory taskContributors = new address[](1);
        taskContributors[0] = admin; // Use the test contract's address for simplicity

        TaskStatus[] memory taskStatuses = new TaskStatus[](1);
        taskStatuses[0] = TaskStatus.Complete;

        uint256[] memory taskContributorTypes = new uint256[](1);
        taskContributorTypes[0] = 1; // Assuming 1 represents some type of contributor

        Task memory initialTask = Task({
            contributionValues: contributionValues,
            taskContributors: taskContributors,
            taskStatus: taskStatuses,
            taskContributorTypes: taskContributorTypes
        });

        Inventory[] memory initialInventory = new Inventory[](1);
        initialInventory[0] = Inventory({
            keyName: "size:one",
            garmentsRemaining: 100
        });

        product = new CrowdmuseProduct(
            500, // _feeNumerator
            10000, // _contributorTotalSupply
            100, // _garmentsAvailable
            initialTask,
            tokenInfo,
            address(usdc),
            "InventoryKey",
            initialInventory,
            false, // _madeToOrder
            admin,
            1 ether // _buyNFTPrice
        );
    }

    function test_name() public view {
        string memory expected = "MyProduct";
        assertEq(
            product.name(),
            expected,
            "Product name does not match expected value."
        );
    }

    function test_symbol() public view {
        string memory expected = "MPROD";
        assertEq(
            product.symbol(),
            expected,
            "Product symbol does not match expected value."
        );
    }

    function test_madeToOrder() public view {
        bool expected = false;
        assertEq(
            product.madeToOrder(),
            expected,
            "Product madeToOrder does not match expected value."
        );
    }

    function test_garmentTypes() public view {
        string memory expected = "size:one";
        assertEq(
            product.garmentTypes(0),
            expected,
            "Product garmentTypes does not match expected value."
        );
    }

    function test_inventoryGarmentsRemaining() public view {
        uint96 expected = 100;
        assertEq(
            product.inventoryGarmentsRemaining(
                keccak256(abi.encodePacked(product.garmentTypes(0)))
            ),
            expected,
            "Product garmentTypes does not match expected value."
        );
    }

    function test_buyNFT() public {
        // Prepare user and admin addresses
        address userAddress = address(0x1);
        bytes32 garmentType = keccak256(abi.encodePacked("size:one"));

        // Transfer some MockUSD to the user to buy an NFT
        uint256 userBalance = 2 ether; // Assuming buyNFTPrice is 1 ether
        usdc.transfer(userAddress, userBalance);
        assertTrue(usdc.balanceOf(userAddress) == userBalance);

        // Ensure the product is complete to allow buying
        assertTrue(product.productStatus() == ProductStatus.Complete);

        // Approve the contract to spend user's MockUSD
        vm.startPrank(userAddress);
        usdc.approve(address(product), userBalance);

        // Buy an NFT
        uint256 quantity = 1;
        uint256 userTokenBalanceBefore = product.balanceOf(userAddress);
        product.buyNFT(userAddress, garmentType, quantity);

        // Check the user now owns 1 more NFT
        uint256 userTokenBalanceAfter = product.balanceOf(userAddress);
        assertTrue(userTokenBalanceAfter == userTokenBalanceBefore + quantity);

        // Check the payment was transferred
        uint256 contractBalance = usdc.balanceOf(address(product));
        assertTrue(contractBalance == 1 ether);

        // Check the garment availability decreased
        uint96 remainingGarments = product.inventoryGarmentsRemaining(
            garmentType
        );
        assertTrue(remainingGarments == 99); // Assuming there were originally 100

        vm.stopPrank();
    }
}
