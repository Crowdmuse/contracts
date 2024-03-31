// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CrowdmuseProduct} from "../../src/CrowdmuseProduct.sol";
import {ICrowdmuseProduct} from "../../src/interfaces/ICrowdmuseProduct.sol";
import {ICrowdmuseEscrow} from "../../src/interfaces/ICrowdmuseEscrow.sol";
import {IMinterStorage} from "../../src/interfaces/IMinterStorage.sol";
import {IMinterErrors} from "../../src/interfaces/IMinterErrors.sol";
import {CrowdmuseEscrowMinter} from "../../src/minters/CrowdmuseEscrowMinter.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract CrowdmuseEscrowMinterTest is
    Test,
    ICrowdmuseEscrow,
    IMinterStorage,
    IMinterErrors
{
    CrowdmuseProduct internal product;
    CrowdmuseEscrowMinter internal minter;
    MockERC20 internal usdc;
    address payable internal admin = payable(address(0x999));
    address payable internal nonAdmin = payable(address(0x666));
    address payable internal protocolFeeRecipient = payable(address(0x7777777));
    address internal tokenRecipient;
    address internal fundsRecipient;

    function setUp() external {
        tokenRecipient = makeAddr("tokenRecipient");
        fundsRecipient = makeAddr("fundsRecipient");

        minter = new CrowdmuseEscrowMinter();
        vm.startPrank(admin);
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
        vm.stopPrank();
    }

    function test_ContractName() external view {
        assertEq(minter.contractName(), "Crowdmuse Basic Minter");
    }

    function test_Version() external view {
        assertEq(minter.contractVersion(), "0.0.1");
    }

    function test_SetSale_OnlyOwner() external {
        SalesConfig memory salesConfig = SalesConfig({
            saleStart: uint64(block.timestamp),
            saleEnd: uint64(block.timestamp + 1 days),
            maxTokensPerAddress: uint64(5),
            pricePerToken: uint96(1 ether),
            fundsRecipient: address(this),
            erc20Address: address(0x333)
        });

        // Encode the expected error for comparison
        bytes memory expectedError = abi.encodeWithSelector(
            Ownable.OwnableUnauthorizedAccount.selector,
            nonAdmin // The address that attempted and failed the authorization check
        );
        // Attempt to set sale config as a non-owner should fail
        vm.prank(address(nonAdmin));
        vm.expectRevert(expectedError);
        minter.setSale(address(product), salesConfig);

        _setSale(salesConfig);

        // Retrieve and validate the set sales configuration
        SalesConfig memory retrievedConfig = minter.sale(address(product));

        // Assertions to check if the stored salesConfig matches the one we set.
        assertEq(
            retrievedConfig.saleStart,
            salesConfig.saleStart,
            "Sale start timestamp mismatch."
        );
        assertEq(
            retrievedConfig.saleEnd,
            salesConfig.saleEnd,
            "Sale end timestamp mismatch."
        );
        assertEq(
            retrievedConfig.maxTokensPerAddress,
            salesConfig.maxTokensPerAddress,
            "Max tokens per address mismatch."
        );
        assertEq(
            retrievedConfig.pricePerToken,
            salesConfig.pricePerToken,
            "Price per token mismatch."
        );
        assertEq(
            retrievedConfig.fundsRecipient,
            salesConfig.fundsRecipient,
            "Funds recipient mismatch."
        );
        assertEq(
            retrievedConfig.erc20Address,
            salesConfig.erc20Address,
            "ERC20 address mismatch."
        );
    }

    function test_MintFlow() external {
        usdc.mint(tokenRecipient, 10 ether);
        bytes32 garmentType = keccak256(abi.encodePacked("size:one"));
        uint256 quantity = 1;
        uint256 initialGarmentsRemaining = product.inventoryGarmentsRemaining(
            garmentType
        );
        uint256 initialRecipientBalance = product.balanceOf(tokenRecipient);
        uint256 initialUsdcBalanceRecipient = usdc.balanceOf(tokenRecipient);
        uint256 initialUsdcBalanceMinter = usdc.balanceOf(address(minter));

        address target = address(product);
        string memory comment = "test comment";
        _setMinterAdmin();

        uint256 newTokenId = product.totalSupply() + 1;

        SalesConfig memory salesConfig = _setMintSale();

        vm.startPrank(tokenRecipient);
        usdc.approve(address(minter), salesConfig.pricePerToken);
        vm.expectEmit(true, true, true, true);
        emit MintComment(tokenRecipient, target, newTokenId, quantity, comment);
        uint256 tokenId = minter.mint(
            target,
            tokenRecipient,
            garmentType,
            quantity,
            comment
        );
        vm.stopPrank();

        uint256 newGarmentsRemaining = product.inventoryGarmentsRemaining(
            garmentType
        );
        uint256 newRecipientBalance = product.balanceOf(tokenRecipient);
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
        assertEq(
            usdc.balanceOf(tokenRecipient),
            initialUsdcBalanceRecipient - salesConfig.pricePerToken * quantity,
            "USDC should be deducted from the buyer."
        );
        assertEq(
            usdc.balanceOf(address(minter)),
            initialUsdcBalanceMinter + salesConfig.pricePerToken * quantity,
            "USDC should be added to the funds recipient."
        );
        bytes32 mintedNFTGarmentType = product.NFTBySize(tokenId);
        assertEq(
            mintedNFTGarmentType,
            garmentType,
            "The minted NFT should have the correct garment type."
        );
    }

    function test_MintFlowAndEscrowDeposit() external {
        _setupEscrowMinter();

        // Set up the minting parameters
        uint256 quantity = 1;
        uint256 pricePerToken = minter.sale(address(product)).pricePerToken;

        // Get the initial balance of the target
        uint256 initialBalanceOfTarget = minter.balanceOf(address(product));
        // Get the expected final balance of the target
        uint256 expectedNewBalance = initialBalanceOfTarget +
            (pricePerToken * quantity);

        _mintToTokenRecipient(quantity);

        // Verify balanceOf is correctly updated
        uint256 newBalanceOfTarget = minter.balanceOf(address(product));
        assertEq(
            newBalanceOfTarget,
            expectedNewBalance,
            "balanceOf[target] should be correctly updated."
        );
    }

    function test_Redeem() public {
        _setupEscrowMinter();

        uint256 initialFundsRecipientBalance = usdc.balanceOf(fundsRecipient);

        _mintToTokenRecipient(1);
        uint256 escrowedAmount = minter.balanceOf(address(product));

        // Expect the EscrowRedeemed event to be emitted with the correct parameters
        vm.expectEmit(true, true, true, true);
        emit EscrowRedeemed(
            address(product),
            fundsRecipient,
            address(usdc),
            escrowedAmount
        );
        _redeemAsAdmin();

        uint256 finalFundsRecipientBalance = usdc.balanceOf(fundsRecipient);
        uint256 finalEscrowBalance = minter.balanceOf(address(product));

        assertEq(
            finalFundsRecipientBalance,
            initialFundsRecipientBalance + escrowedAmount,
            "FundsRecipient did not receive the correct amount of USDC"
        );
        assertEq(
            finalEscrowBalance,
            0,
            "Escrow balance should be zero after redemption"
        );
    }

    function test_Redeem_OnlyOwnerCanCall(address _nonAdmin) external {
        _setupEscrowMinter();
        _mintToTokenRecipient(10); // Assume this mints tokens and accumulates some amount in escrow

        // Attempt to redeem as a non-owner should fail with OwnableUnauthorizedAccount error
        bytes memory expectedError = abi.encodeWithSelector(
            Ownable.OwnableUnauthorizedAccount.selector,
            _nonAdmin
        );
        vm.expectRevert(expectedError);

        vm.prank(_nonAdmin);
        minter.redeem(address(product));
    }

    function test_Redeem_ConfigDeletedAfterRedemption() external {
        _setupEscrowMinter();
        _mintToTokenRecipient(10);

        // Redeem as the owner should succeed
        _redeemAsAdmin();

        // After redemption, attempt to access the product's sales configuration
        SalesConfig memory configAfterRedemption = minter.sale(
            address(product)
        );

        // Define expected default values for a SalesConfig struct
        SalesConfig memory defaultConfig;

        // Verify that the sales configuration matches the default (indicating it was deleted)
        assertTrue(
            _compareSalesConfig(configAfterRedemption, defaultConfig),
            "Sales configuration was not deleted after redemption."
        );
    }

    function test_Redeem_MintingFailsWithSaleEndedAfterRedeem() external {
        _setupEscrowMinter();
        _mintToTokenRecipient(10);
        _redeemAsAdmin();

        // Attempt to mint tokens after the sale has been redeemed
        vm.prank(tokenRecipient);
        usdc.approve(address(minter), 1 ether);
        vm.expectRevert(SaleEnded.selector);
        minter.mint(
            address(product),
            tokenRecipient,
            keccak256("size:one"),
            1,
            "Minting after redeem"
        );
    }

    // TEST UTILS
    function _setupEscrowMinter() internal {
        // Set up the sales configuration for the product
        _setMintSale();
        // Make the minter admin
        _setMinterAdmin();
    }

    function _setMinterAdmin() internal {
        vm.prank(admin);
        product.changeAdmin(address(minter));
    }

    function _setMintSale() internal returns (SalesConfig memory salesConfig) {
        salesConfig = SalesConfig({
            saleStart: uint64(block.timestamp),
            saleEnd: uint64(block.timestamp + 1 days),
            maxTokensPerAddress: uint64(500),
            pricePerToken: uint96(1 ether),
            fundsRecipient: fundsRecipient,
            erc20Address: address(usdc)
        });

        _setSale(salesConfig);
    }

    function _setSale(SalesConfig memory salesConfig) internal {
        // Set sale config as the owner should succeed
        vm.prank(admin); // Assuming `admin` is the owner
        minter.setSale(address(product), salesConfig);
    }

    function _mintToTokenRecipient(uint256 quantity) internal {
        // Set up the minting parameters
        bytes32 garmentType = keccak256(abi.encodePacked("size:one"));
        uint256 pricePerToken = minter.sale(address(product)).pricePerToken;
        // Approve the minter contract to spend the buyer's USDC
        vm.startPrank(tokenRecipient);
        usdc.mint(tokenRecipient, 10 ether);
        usdc.approve(address(minter), pricePerToken * quantity);

        // Expect the EscrowDeposit event to be emitted
        vm.expectEmit(true, true, true, true);
        emit EscrowDeposit(
            address(product),
            tokenRecipient,
            pricePerToken * quantity
        );

        // Call the mint function
        minter.mint(
            address(product),
            tokenRecipient,
            garmentType,
            quantity,
            "Test comment"
        );
        vm.stopPrank();
    }

    // Utility function to compare two SalesConfig structs
    function _compareSalesConfig(
        SalesConfig memory a,
        SalesConfig memory b
    ) internal pure returns (bool) {
        return
            a.saleStart == b.saleStart &&
            a.saleEnd == b.saleEnd &&
            a.maxTokensPerAddress == b.maxTokensPerAddress &&
            a.pricePerToken == b.pricePerToken &&
            a.fundsRecipient == b.fundsRecipient &&
            a.erc20Address == b.erc20Address;
    }

    function _redeemAsAdmin() internal {
        vm.prank(admin);
        minter.redeem(address(product));
    }
}
