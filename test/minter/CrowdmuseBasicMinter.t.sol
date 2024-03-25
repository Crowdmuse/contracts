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

    // function test_MintBatchFlow() external {
    //     vm.startPrank(admin);
    //     uint96 pricePerToken = 100;
    //     uint256 numTokens = 10;
    //     uint256 newTokenId = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         numTokens
    //     );
    //     uint256 newTokenId2 = target.setupNewToken(
    //         "https://zora.co/testing/token2.json",
    //         numTokens
    //     );
    //     uint256 newTokenId3 = target.setupNewToken(
    //         "https://zora.co/testing/token3.json",
    //         numTokens
    //     );

    //     address[] memory targets = new address[](3); // Dynamically-sized array
    //     uint256[] memory tokens = new uint256[](3); // Dynamically-sized array
    //     uint256[] memory quantities = new uint256[](3); // Dynamically-sized array
    //     bytes[] memory minterArguments = new bytes[](3);

    //     tokens[0] = newTokenId;
    //     tokens[1] = newTokenId2;
    //     tokens[2] = newTokenId3;
    //     targets[0] = address(target);
    //     targets[1] = address(target);
    //     targets[2] = address(target);
    //     quantities[0] = numTokens;
    //     quantities[1] = numTokens;
    //     quantities[2] = numTokens;

    //     for (uint256 i = 0; i < tokens.length; i++) {
    //         // GRANT MINTER ADMIN ROLE - adminMint (skip zora fee)
    //         target.addPermission(
    //             tokens[i],
    //             address(fixedPriceErc20),
    //             target.PERMISSION_BIT_ADMIN()
    //         );

    //         // CREATOR CALLS callSale on CREATORCROP
    //         vm.expectEmit(true, true, true, true);
    //         emit SaleSet(
    //             address(target),
    //             tokens[i],
    //             CrowdmuseBasicMinter.SalesConfig({
    //                 pricePerToken: pricePerToken,
    //                 saleStart: 0,
    //                 saleEnd: type(uint64).max,
    //                 maxTokensPerAddress: 0,
    //                 fundsRecipient: fundsRecipient,
    //                 erc20Address: address(usdc)
    //             })
    //         );
    //         target.callSale(
    //             tokens[i],
    //             fixedPriceErc20,
    //             abi.encodeWithSelector(
    //                 CrowdmuseBasicMinter.setSale.selector,
    //                 tokens[i],
    //                 CrowdmuseBasicMinter.SalesConfig({
    //                     pricePerToken: pricePerToken,
    //                     saleStart: 0,
    //                     saleEnd: type(uint64).max,
    //                     maxTokensPerAddress: 0,
    //                     fundsRecipient: fundsRecipient,
    //                     erc20Address: address(usdc)
    //                 })
    //             )
    //         );

    //         minterArguments[i] = abi.encode(tokenRecipient, "");
    //     }

    //     vm.stopPrank();

    //     // AIRDROP USDC
    //     uint256 totalValue = (pricePerToken * numTokens * tokens.length);
    //     vm.prank(admin);
    //     usdc.mint(tokenRecipient, totalValue);

    //     // COLLECTOR APPROVED USDC for MINTER
    //     vm.startPrank(tokenRecipient);
    //     usdc.approve(address(fixedPriceErc20), totalValue);

    //     // COLLECTOR CALL requestBatchMint
    //     fixedPriceErc20.requestMintBatch(
    //         targets,
    //         tokens,
    //         quantities,
    //         0,
    //         minterArguments
    //     );

    //     // VERIFY COLLECT
    //     for (uint256 i = 0; i < tokens.length; i++) {
    //         assertEq(target.balanceOf(tokenRecipient, tokens[i]), numTokens);
    //     }

    //     // VERIFY USDC PAYMENT
    //     test_USDCPayouts(totalValue);
    //     vm.stopPrank();
    // }

    // function test_MintWithCommentBackwardsCompatible() external {
    //     vm.startPrank(admin);
    //     uint256 newTokenId = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         10
    //     );
    //     target.addPermission(
    //         newTokenId,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_ADMIN()
    //     );
    //     vm.expectEmit(true, true, true, true);
    //     emit SaleSet(
    //         address(target),
    //         newTokenId,
    //         CrowdmuseBasicMinter.SalesConfig({
    //             pricePerToken: 1 ether,
    //             saleStart: 0,
    //             saleEnd: type(uint64).max,
    //             maxTokensPerAddress: 0,
    //             fundsRecipient: fundsRecipient,
    //             erc20Address: address(usdc)
    //         })
    //     );
    //     target.callSale(
    //         newTokenId,
    //         fixedPriceErc20,
    //         abi.encodeWithSelector(
    //             CrowdmuseBasicMinter.setSale.selector,
    //             newTokenId,
    //             CrowdmuseBasicMinter.SalesConfig({
    //                 pricePerToken: 1 ether,
    //                 saleStart: 0,
    //                 saleEnd: type(uint64).max,
    //                 maxTokensPerAddress: 0,
    //                 fundsRecipient: fundsRecipient,
    //                 erc20Address: address(usdc)
    //             })
    //         )
    //     );
    //     vm.stopPrank();

    //     uint256 numTokens = 10;
    //     uint256 totalValue = (1 ether * numTokens);

    //     vm.prank(admin);
    //     usdc.mint(tokenRecipient, totalValue);

    //     vm.startPrank(tokenRecipient);
    //     usdc.approve(address(fixedPriceErc20), totalValue);
    //     fixedPriceErc20.requestMint(
    //         address(target),
    //         newTokenId,
    //         numTokens,
    //         0,
    //         abi.encode(tokenRecipient, "")
    //     );

    //     assertEq(target.balanceOf(tokenRecipient, newTokenId), numTokens);
    //     test_USDCPayouts(totalValue);

    //     vm.stopPrank();
    // }

    // function test_MintWithComment() external {
    //     vm.startPrank(admin);
    //     uint256 newTokenId = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         10
    //     );
    //     target.addPermission(
    //         newTokenId,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_ADMIN()
    //     );
    //     vm.expectEmit(true, true, true, true);
    //     emit SaleSet(
    //         address(target),
    //         newTokenId,
    //         CrowdmuseBasicMinter.SalesConfig({
    //             pricePerToken: 1 ether,
    //             saleStart: 0,
    //             saleEnd: type(uint64).max,
    //             maxTokensPerAddress: 0,
    //             fundsRecipient: fundsRecipient,
    //             erc20Address: address(usdc)
    //         })
    //     );
    //     target.callSale(
    //         newTokenId,
    //         fixedPriceErc20,
    //         abi.encodeWithSelector(
    //             CrowdmuseBasicMinter.setSale.selector,
    //             newTokenId,
    //             CrowdmuseBasicMinter.SalesConfig({
    //                 pricePerToken: 1 ether,
    //                 saleStart: 0,
    //                 saleEnd: type(uint64).max,
    //                 maxTokensPerAddress: 0,
    //                 fundsRecipient: fundsRecipient,
    //                 erc20Address: address(usdc)
    //             })
    //         )
    //     );
    //     vm.stopPrank();

    //     uint256 numTokens = 10;
    //     uint256 totalValue = (1 ether * numTokens);

    //     vm.prank(admin);
    //     usdc.mint(tokenRecipient, totalValue);

    //     vm.startPrank(tokenRecipient);
    //     usdc.approve(address(fixedPriceErc20), totalValue);
    //     vm.expectEmit(true, true, true, true);
    //     emit MintComment(
    //         tokenRecipient,
    //         address(target),
    //         newTokenId,
    //         numTokens,
    //         "test comment"
    //     );
    //     fixedPriceErc20.requestMint(
    //         address(target),
    //         newTokenId,
    //         numTokens,
    //         0,
    //         abi.encode(tokenRecipient, "test comment")
    //     );

    //     assertEq(target.balanceOf(tokenRecipient, newTokenId), numTokens);
    //     test_USDCPayouts(totalValue);
    //     vm.stopPrank();
    // }

    // function test_SaleStart() external {
    //     vm.startPrank(admin);
    //     uint256 newTokenId = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         10
    //     );
    //     target.addPermission(
    //         newTokenId,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_ADMIN()
    //     );
    //     target.callSale(
    //         newTokenId,
    //         fixedPriceErc20,
    //         abi.encodeWithSelector(
    //             CrowdmuseBasicMinter.setSale.selector,
    //             newTokenId,
    //             CrowdmuseBasicMinter.SalesConfig({
    //                 pricePerToken: 1 ether,
    //                 saleStart: uint64(block.timestamp + 1 days),
    //                 saleEnd: type(uint64).max,
    //                 maxTokensPerAddress: 10,
    //                 fundsRecipient: fundsRecipient,
    //                 erc20Address: address(usdc)
    //             })
    //         )
    //     );
    //     vm.stopPrank();

    //     vm.prank(admin);
    //     usdc.mint(tokenRecipient, 20 ether);

    //     vm.expectRevert(abi.encodeWithSignature("SaleHasNotStarted()"));
    //     vm.prank(tokenRecipient);
    //     fixedPriceErc20.requestMint(
    //         address(target),
    //         newTokenId,
    //         10,
    //         0,
    //         abi.encode(tokenRecipient)
    //     );
    // }

    // function test_WrongValueSent() external {
    //     uint96 pricePerToken = 1 ether;

    //     vm.startPrank(admin);
    //     uint256 newTokenId = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         10
    //     );
    //     target.addPermission(
    //         newTokenId,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_ADMIN()
    //     );
    //     target.callSale(
    //         newTokenId,
    //         fixedPriceErc20,
    //         abi.encodeWithSelector(
    //             CrowdmuseBasicMinter.setSale.selector,
    //             newTokenId,
    //             CrowdmuseBasicMinter.SalesConfig({
    //                 pricePerToken: pricePerToken,
    //                 saleStart: 0,
    //                 saleEnd: type(uint64).max,
    //                 maxTokensPerAddress: 11,
    //                 fundsRecipient: fundsRecipient,
    //                 erc20Address: address(usdc)
    //             })
    //         )
    //     );
    //     vm.stopPrank();

    //     vm.prank(admin);
    //     usdc.mint(tokenRecipient, 20 ether);
    //     vm.startPrank(tokenRecipient);
    //     vm.expectRevert(abi.encodeWithSignature("WrongValueSent()"));
    //     fixedPriceErc20.requestMint(
    //         address(target),
    //         newTokenId,
    //         10,
    //         0,
    //         abi.encode(tokenRecipient)
    //     );
    // }

    // function test_SaleEnd() external {
    //     vm.warp(2 days);

    //     vm.startPrank(admin);
    //     uint256 newTokenId = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         10
    //     );
    //     target.addPermission(
    //         newTokenId,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_ADMIN()
    //     );
    //     target.callSale(
    //         newTokenId,
    //         fixedPriceErc20,
    //         abi.encodeWithSelector(
    //             CrowdmuseBasicMinter.setSale.selector,
    //             newTokenId,
    //             CrowdmuseBasicMinter.SalesConfig({
    //                 pricePerToken: 1 ether,
    //                 saleStart: 0,
    //                 saleEnd: uint64(1 days),
    //                 maxTokensPerAddress: 0,
    //                 fundsRecipient: fundsRecipient,
    //                 erc20Address: address(usdc)
    //             })
    //         )
    //     );
    //     vm.stopPrank();

    //     vm.expectRevert(abi.encodeWithSignature("SaleEnded()"));
    //     vm.prank(tokenRecipient);
    //     fixedPriceErc20.requestMint(
    //         address(target),
    //         newTokenId,
    //         10,
    //         0,
    //         abi.encode(tokenRecipient)
    //     );
    // }

    // function test_MaxTokensPerAddress() external {
    //     vm.warp(2 days);

    //     vm.startPrank(admin);
    //     uint256 newTokenId = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         10
    //     );
    //     target.addPermission(
    //         newTokenId,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_ADMIN()
    //     );
    //     target.callSale(
    //         newTokenId,
    //         fixedPriceErc20,
    //         abi.encodeWithSelector(
    //             CrowdmuseBasicMinter.setSale.selector,
    //             newTokenId,
    //             CrowdmuseBasicMinter.SalesConfig({
    //                 pricePerToken: 1 ether,
    //                 saleStart: 0,
    //                 saleEnd: type(uint64).max,
    //                 maxTokensPerAddress: 5,
    //                 fundsRecipient: fundsRecipient,
    //                 erc20Address: address(usdc)
    //             })
    //         )
    //     );
    //     vm.stopPrank();

    //     uint256 numTokens = 6;
    //     uint256 totalValue = (1 ether * numTokens);

    //     vm.prank(admin);
    //     usdc.mint(tokenRecipient, totalValue);

    //     vm.startPrank(tokenRecipient);
    //     usdc.approve(address(fixedPriceErc20), totalValue);
    //     vm.expectRevert();
    //     fixedPriceErc20.requestMint(
    //         address(target),
    //         newTokenId,
    //         numTokens,
    //         0,
    //         abi.encode(tokenRecipient)
    //     );
    // }

    // function testFail_setupMint() external {
    //     vm.startPrank(admin);
    //     uint256 newTokenId = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         10
    //     );
    //     target.addPermission(
    //         newTokenId,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_ADMIN()
    //     );
    //     target.callSale(
    //         newTokenId,
    //         fixedPriceErc20,
    //         abi.encodeWithSelector(
    //             CrowdmuseBasicMinter.setSale.selector,
    //             newTokenId,
    //             CrowdmuseBasicMinter.SalesConfig({
    //                 pricePerToken: 1 ether,
    //                 saleStart: 0,
    //                 saleEnd: type(uint64).max,
    //                 maxTokensPerAddress: 9,
    //                 fundsRecipient: fundsRecipient,
    //                 erc20Address: address(usdc)
    //             })
    //         )
    //     );
    //     vm.stopPrank();

    //     vm.prank(admin);
    //     usdc.mint(tokenRecipient, 20 ether);

    //     vm.startPrank(tokenRecipient);
    //     usdc.approve(address(fixedPriceErc20), 10 ether);
    //     fixedPriceErc20.requestMint(
    //         address(target),
    //         newTokenId,
    //         10,
    //         0,
    //         abi.encode(tokenRecipient)
    //     );

    //     assertEq(target.balanceOf(tokenRecipient, newTokenId), 10);
    //     assertEq(usdc.balanceOf(fundsRecipient), 10 ether);

    //     vm.stopPrank();
    // }

    // function test_PricePerToken() external {
    //     vm.warp(2 days);

    //     vm.startPrank(admin);
    //     uint256 newTokenId = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         10
    //     );
    //     target.addPermission(
    //         newTokenId,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_ADMIN()
    //     );
    //     target.callSale(
    //         newTokenId,
    //         fixedPriceErc20,
    //         abi.encodeWithSelector(
    //             CrowdmuseBasicMinter.setSale.selector,
    //             newTokenId,
    //             CrowdmuseBasicMinter.SalesConfig({
    //                 pricePerToken: 1 ether,
    //                 saleStart: 0,
    //                 saleEnd: type(uint64).max,
    //                 maxTokensPerAddress: 0,
    //                 fundsRecipient: fundsRecipient,
    //                 erc20Address: address(usdc)
    //             })
    //         )
    //     );
    //     vm.stopPrank();

    //     vm.prank(admin);
    //     usdc.mint(tokenRecipient, 20 ether);

    //     vm.startPrank(tokenRecipient);

    //     usdc.approve(address(fixedPriceErc20), 1 ether);
    //     fixedPriceErc20.requestMint(
    //         address(target),
    //         newTokenId,
    //         1,
    //         0,
    //         abi.encode(tokenRecipient, "")
    //     );

    //     vm.stopPrank();
    // }

    // function test_FundsRecipient() external {
    //     uint96 pricePerToken = 1 ether;
    //     uint256 numTokens = 10;

    //     vm.startPrank(admin);
    //     uint256 newTokenId = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         10
    //     );
    //     target.addPermission(
    //         newTokenId,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_ADMIN()
    //     );
    //     target.callSale(
    //         newTokenId,
    //         fixedPriceErc20,
    //         abi.encodeWithSelector(
    //             CrowdmuseBasicMinter.setSale.selector,
    //             newTokenId,
    //             CrowdmuseBasicMinter.SalesConfig({
    //                 pricePerToken: pricePerToken,
    //                 saleStart: 0,
    //                 saleEnd: type(uint64).max,
    //                 maxTokensPerAddress: 0,
    //                 fundsRecipient: fundsRecipient,
    //                 erc20Address: address(usdc)
    //             })
    //         )
    //     );
    //     vm.stopPrank();

    //     uint256 totalValue = (pricePerToken * numTokens);

    //     vm.prank(admin);
    //     usdc.mint(tokenRecipient, totalValue);

    //     vm.startPrank(tokenRecipient);
    //     usdc.approve(address(fixedPriceErc20), totalValue);
    //     fixedPriceErc20.requestMint(
    //         address(target),
    //         newTokenId,
    //         numTokens,
    //         0,
    //         abi.encode(tokenRecipient, "")
    //     );
    //     test_USDCPayouts(10 ether);
    // }

    // function test_SetFundsRecipient() external {
    //     uint96 pricePerToken = 1 ether;
    //     uint256 numTokens = 10;

    //     vm.startPrank(admin);
    //     uint256 newTokenId = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         10
    //     );
    //     target.addPermission(
    //         newTokenId,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_ADMIN()
    //     );
    //     target.callSale(
    //         newTokenId,
    //         fixedPriceErc20,
    //         abi.encodeWithSelector(
    //             CrowdmuseBasicMinter.setSale.selector,
    //             newTokenId,
    //             CrowdmuseBasicMinter.SalesConfig({
    //                 pricePerToken: pricePerToken,
    //                 saleStart: 0,
    //                 saleEnd: type(uint64).max,
    //                 maxTokensPerAddress: 0,
    //                 fundsRecipient: fundsRecipient,
    //                 erc20Address: address(usdc)
    //             })
    //         )
    //     );
    //     vm.stopPrank();

    //     uint256 totalValue = (pricePerToken * numTokens);

    //     vm.prank(admin);
    //     usdc.mint(tokenRecipient, totalValue);

    //     address newFundsRecipient = address(0x1111);
    //     // REVERT - SET PROTOCOL FEE RECIPIENT
    //     vm.expectRevert("Not protocol fee recipient");
    //     fixedPriceErc20.setProtocolFeeRecipient(newFundsRecipient);

    //     // SET PROTOCOL FEE RECIPIENT
    //     vm.prank(protocolFeeRecipient);
    //     fixedPriceErc20.setProtocolFeeRecipient(newFundsRecipient);

    //     vm.startPrank(tokenRecipient);
    //     usdc.approve(address(fixedPriceErc20), totalValue);
    //     fixedPriceErc20.requestMint(
    //         address(target),
    //         newTokenId,
    //         numTokens,
    //         0,
    //         abi.encode(tokenRecipient, "")
    //     );
    //     uint256 protocolFee = 10 ether / 20;
    //     uint256 creatorFee = 10 ether - protocolFee;
    //     assertEq(usdc.balanceOf(protocolFeeRecipient), 0);
    //     assertEq(usdc.balanceOf(newFundsRecipient), protocolFee);
    //     assertEq(usdc.balanceOf(fundsRecipient), creatorFee);
    // }

    // function test_MintedPerRecipientGetter() external {
    //     vm.startPrank(admin);
    //     uint256 newTokenId = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         10
    //     );
    //     target.addPermission(
    //         newTokenId,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_ADMIN()
    //     );
    //     target.callSale(
    //         newTokenId,
    //         fixedPriceErc20,
    //         abi.encodeWithSelector(
    //             CrowdmuseBasicMinter.setSale.selector,
    //             newTokenId,
    //             CrowdmuseBasicMinter.SalesConfig({
    //                 pricePerToken: 0 ether,
    //                 saleStart: 0,
    //                 saleEnd: type(uint64).max,
    //                 maxTokensPerAddress: 20,
    //                 fundsRecipient: fundsRecipient,
    //                 erc20Address: address(usdc)
    //             })
    //         )
    //     );
    //     vm.stopPrank();

    //     uint256 numTokens = 10;

    //     vm.prank(tokenRecipient);
    //     fixedPriceErc20.requestMint(
    //         address(target),
    //         newTokenId,
    //         numTokens,
    //         0,
    //         abi.encode(tokenRecipient, "")
    //     );

    //     assertEq(
    //         fixedPriceErc20.getMintedPerWallet(
    //             address(target),
    //             newTokenId,
    //             tokenRecipient
    //         ),
    //         numTokens
    //     );
    // }

    // function test_ResetSale() external {
    //     vm.startPrank(admin);
    //     uint256 newTokenId = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         10
    //     );
    //     target.addPermission(
    //         newTokenId,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_MINTER()
    //     );
    //     vm.expectEmit(false, false, false, false);
    //     emit SaleSet(
    //         address(target),
    //         newTokenId,
    //         CrowdmuseBasicMinter.SalesConfig({
    //             pricePerToken: 0,
    //             saleStart: 0,
    //             saleEnd: 0,
    //             maxTokensPerAddress: 0,
    //             fundsRecipient: address(0),
    //             erc20Address: address(0)
    //         })
    //     );
    //     target.callSale(
    //         newTokenId,
    //         fixedPriceErc20,
    //         abi.encodeWithSelector(
    //             CrowdmuseBasicMinter.resetSale.selector,
    //             newTokenId
    //         )
    //     );
    //     vm.stopPrank();

    //     CrowdmuseBasicMinter.SalesConfig memory sale = fixedPriceErc20.sale(
    //         address(target),
    //         newTokenId
    //     );
    //     assertEq(sale.pricePerToken, 0);
    //     assertEq(sale.saleStart, 0);
    //     assertEq(sale.saleEnd, 0);
    //     assertEq(sale.maxTokensPerAddress, 0);
    //     assertEq(sale.fundsRecipient, address(0));
    //     assertEq(sale.erc20Address, address(0));
    // }

    // function test_SaleERC20Address() external {
    //     vm.startPrank(admin);
    //     uint256 newTokenId = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         10
    //     );
    //     target.addPermission(
    //         newTokenId,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_MINTER()
    //     );
    //     target.callSale(
    //         newTokenId,
    //         fixedPriceErc20,
    //         abi.encodeWithSelector(
    //             CrowdmuseBasicMinter.setSale.selector,
    //             newTokenId,
    //             CrowdmuseBasicMinter.SalesConfig({
    //                 pricePerToken: 0,
    //                 saleStart: 0,
    //                 saleEnd: 0,
    //                 maxTokensPerAddress: 0,
    //                 fundsRecipient: address(0),
    //                 erc20Address: address(usdc)
    //             })
    //         )
    //     );
    //     vm.stopPrank();

    //     CrowdmuseBasicMinter.SalesConfig memory sale = fixedPriceErc20.sale(
    //         address(target),
    //         newTokenId
    //     );
    //     assertEq(sale.pricePerToken, 0);
    //     assertEq(sale.saleStart, 0);
    //     assertEq(sale.saleEnd, 0);
    //     assertEq(sale.maxTokensPerAddress, 0);
    //     assertEq(sale.fundsRecipient, address(0));
    //     assertEq(sale.erc20Address, address(usdc));
    // }

    // function test_fixedPriceSaleSupportsInterface() public {
    //     assertTrue(fixedPriceErc20.supportsInterface(0x6890e5b3));
    //     assertTrue(fixedPriceErc20.supportsInterface(0x01ffc9a7));
    //     assertFalse(fixedPriceErc20.supportsInterface(0x0));
    // }

    // function testRevert_CannotSetSaleOfDifferentTokenId() public {
    //     vm.startPrank(admin);
    //     uint256 tokenId1 = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         10
    //     );
    //     uint256 tokenId2 = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         5
    //     );

    //     target.addPermission(
    //         tokenId1,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_MINTER()
    //     );
    //     target.addPermission(
    //         tokenId2,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_MINTER()
    //     );

    //     vm.expectRevert(abi.encodeWithSignature("Call_TokenIdMismatch()"));
    //     target.callSale(
    //         tokenId1,
    //         fixedPriceErc20,
    //         abi.encodeWithSelector(
    //             CrowdmuseBasicMinter.setSale.selector,
    //             tokenId2,
    //             CrowdmuseBasicMinter.SalesConfig({
    //                 pricePerToken: 1 ether,
    //                 saleStart: 0,
    //                 saleEnd: type(uint64).max,
    //                 maxTokensPerAddress: 0,
    //                 fundsRecipient: address(0),
    //                 erc20Address: address(0)
    //             })
    //         )
    //     );
    //     vm.stopPrank();
    // }

    // function testRevert_CannotResetSaleOfDifferentTokenId() public {
    //     vm.startPrank(admin);
    //     uint256 tokenId1 = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         10
    //     );
    //     uint256 tokenId2 = target.setupNewToken(
    //         "https://zora.co/testing/token.json",
    //         5
    //     );

    //     target.addPermission(
    //         tokenId1,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_MINTER()
    //     );
    //     target.addPermission(
    //         tokenId2,
    //         address(fixedPriceErc20),
    //         target.PERMISSION_BIT_MINTER()
    //     );

    //     vm.expectRevert(abi.encodeWithSignature("Call_TokenIdMismatch()"));
    //     target.callSale(
    //         tokenId1,
    //         fixedPriceErc20,
    //         abi.encodeWithSelector(
    //             CrowdmuseBasicMinter.resetSale.selector,
    //             tokenId2
    //         )
    //     );
    //     vm.stopPrank();
    // }

    // function test_USDCPayouts(uint256 totalValue) internal {
    //     uint256 protocolFee = totalValue / 20;
    //     uint256 creatorFee = totalValue - protocolFee;
    //     assertEq(usdc.balanceOf(protocolFeeRecipient), protocolFee);
    //     assertEq(usdc.balanceOf(fundsRecipient), creatorFee);
    // }
}
