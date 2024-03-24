// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {CrowdmuseProduct} from "../src/CrowdmuseProduct.sol";
import {ICrowdmuseProduct} from "../src/interfaces/ICrowdmuseProduct.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 for testing purposes
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1e24); // Mint 1 million tokens for the deployer
    }
}

contract CrowdmuseProductTest is Test, ICrowdmuseProduct {
    CrowdmuseProduct public product;
    MockERC20 public paymentToken;
    address admin;

    function setUp() public {
        admin = address(this); // For simplicity, let the test contract be the admin
        paymentToken = new MockERC20("MockUSD", "MUSD");

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
            address(paymentToken),
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

    function test_garmentTypes() public {
        string memory expected = "size:one";
        assertEq(
            product.garmentTypes(0),
            expected,
            "Product garmentTypes does not match expected value."
        );
    }

    function test_inventoryGarmentsRemaining() public {
        uint96 expected = 100;
        assertEq(
            product.inventoryGarmentsRemaining(
                keccak256(abi.encodePacked(product.garmentTypes(0)))
            ),
            expected,
            "Product garmentTypes does not match expected value."
        );
    }
}
