// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {CrowdmuseProduct} from "../../src/CrowdmuseProduct.sol";
import {ICrowdmuseProduct} from "../../src/interfaces/ICrowdmuseProduct.sol";
import {CrowdmuseBasicMinter} from "../../src/minters/CrowdmuseBasicMinter.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract CrowdmuseBasicMinterTest is Test {
    CrowdmuseProduct internal product;
    CrowdmuseBasicMinter internal minter;
    MockERC20 internal usdc;
    address payable internal admin = payable(address(0x999));
    address payable internal protocolFeeRecipient = payable(address(0x7777777));
    address internal zora;
    address internal tokenRecipient;
    address internal fundsRecipient;

    event SaleSet(
        address indexed mediaContract,
        uint256 indexed tokenId,
        CrowdmuseBasicMinter.SalesConfig salesConfig
    );
    event MintComment(
        address indexed sender,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 quantity,
        string comment
    );

    function setUp() external {
        zora = makeAddr("zora");
        tokenRecipient = makeAddr("tokenRecipient");
        fundsRecipient = makeAddr("fundsRecipient");

        minter = new CrowdmuseBasicMinter(protocolFeeRecipient);
        vm.prank(admin);
        admin = payable(address(this));
        usdc = new MockERC20("MockUSD", "MUSD");
        ICrowdmuseProduct.Token memory tokenInfo = ICrowdmuseProduct.Token({
            productName: "MyProduct",
            productSymbol: "MPROD",
            baseUri: "ipfs://baseuri/",
            maxAmountOfTokensPerMint: 10
        });
        uint256[] memory contributionValues = new uint256[](1);
        contributionValues[0] = 1000;
        address[] memory taskContributors = new address[](1);
        taskContributors[0] = admin;
        ICrowdmuseProduct.TaskStatus[]
            memory taskStatuses = new ICrowdmuseProduct.TaskStatus[](1);
        taskStatuses[0] = ICrowdmuseProduct.TaskStatus.Complete;
        uint256[] memory taskContributorTypes = new uint256[](1);
        taskContributorTypes[0] = 1;
        ICrowdmuseProduct.Task memory initialTask = ICrowdmuseProduct.Task({
            contributionValues: contributionValues,
            taskContributors: taskContributors,
            taskStatus: taskStatuses,
            taskContributorTypes: taskContributorTypes
        });
        ICrowdmuseProduct.Inventory[]
            memory initialInventory = new ICrowdmuseProduct.Inventory[](1);
        initialInventory[0] = ICrowdmuseProduct.Inventory({
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

    function test_ContractName() external view {
        assertEq(minter.contractName(), "Crowdmuse Basic Minter");
    }

    function test_Version() external view {
        assertEq(minter.contractVersion(), "0.0.1");
    }

    function test_MintFlow() external {
        address recipient = address(0x123);
        bytes32 garmentType = keccak256(abi.encodePacked("size:one"));
        uint256 quantity = 1;
        uint256 initialGarmentsRemaining = product.inventoryGarmentsRemaining(
            garmentType
        );
        uint256 initialRecipientBalance = product.balanceOf(recipient);

        address target = address(product);
        address mintTo = recipient;
        string memory comment = "test comment";
        vm.prank(admin);
        product.changeAdmin(address(minter));

        vm.prank(tokenRecipient);
        uint256 tokenId = minter.mint(
            target,
            mintTo,
            garmentType,
            quantity,
            comment
        );
        uint256 newGarmentsRemaining = product.inventoryGarmentsRemaining(
            garmentType
        );
        uint256 newRecipientBalance = product.balanceOf(recipient);
        assertEq(
            newGarmentsRemaining,
            initialGarmentsRemaining - quantity,
            "Garment inventory should decrease by the quantity minted."
        );
        assertEq(
            newRecipientBalance,
            initialRecipientBalance + quantity,
            "Recipient should have more NFTs after minting."
        );
        bytes32 mintedNFTGarmentType = product.NFTBySize(tokenId);
        assertEq(
            mintedNFTGarmentType,
            garmentType,
            "The minted NFT should have the correct garment type."
        );
    }
}
