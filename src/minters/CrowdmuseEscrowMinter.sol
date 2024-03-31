// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LimitedMintPerAddress} from "../utils/LimitedMintPerAddress.sol";
import {IMinterErrors} from "../interfaces/IMinterErrors.sol";
import {ICrowdmuseProduct} from "../interfaces/ICrowdmuseProduct.sol";
import {ICrowdmuseEscrow} from "../interfaces/ICrowdmuseEscrow.sol";
import {IMinterStorage} from "../interfaces/IMinterStorage.sol";

/// @title CrowdmuseEscrowMinter
/// @notice A minter that allows for basic purchasing on Crowdmuse
contract CrowdmuseEscrowMinter is
    LimitedMintPerAddress,
    ICrowdmuseEscrow,
    IMinterErrors,
    IMinterStorage
{
    // product -> settings
    mapping(address => SalesConfig) internal salesConfigs;
    /// @notice A product's escrow balance
    mapping(address => uint256) public balanceOf;

    /// @notice Retrieves the contract metadata URI
    /// @return A string representing the metadata URI for this contract
    function contractURI() external pure returns (string memory) {
        return "https://github.com/Crowdmuse/contracts";
    }

    /// @notice Retrieves the name of the minter contract
    /// @return A string representing the name of this minter contract
    function contractName() external pure returns (string memory) {
        return "Crowdmuse Basic Minter";
    }

    /// @notice Retrieves the version of the minter contract
    /// @return A string representing the version of this minter contract
    function contractVersion() external pure returns (string memory) {
        return "0.0.1";
    }

    /// @dev Emitted when a mint operation includes a comment
    /// @param sender The address that initiated the mint operation
    /// @param tokenContract The address of the token contract where the mint occurred
    /// @param tokenId The ID of the token that was minted
    /// @param quantity The quantity of tokens minted
    /// @param comment A comment provided during the minting process
    event MintComment(
        address indexed sender,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 quantity,
        string comment
    );

    /// @notice Mints tokens to a specified address with an optional comment
    /// @param target The target CrowdmuseProduct contract address where the mint will occur
    /// @param mintTo The address that will receive the minted tokens
    /// @param garmentType The type of garment being minted, represented as a bytes32 hash
    /// @param quantity The quantity of tokens to mint
    /// @param comment An optional comment provided for the minting operation
    /// @return tokenId The token ID of the last minted token
    function mint(
        address target,
        address mintTo,
        bytes32 garmentType,
        uint256 quantity,
        string memory comment
    ) external returns (uint256 tokenId) {
        tokenId = _mint(target, mintTo, garmentType, quantity, comment);
    }

    /// @dev Internal function to handle the minting operation
    /// @param target The target CrowdmuseProduct contract address where the mint will occur
    /// @param mintTo The address that will receive the minted tokens
    /// @param garmentType The type of garment being minted, represented as a bytes32 hash
    /// @param quantity The quantity of tokens to mint
    /// @param comment An optional comment provided for the minting operation
    /// @return tokenId The token ID of the last minted token
    function _mint(
        address target,
        address mintTo,
        bytes32 garmentType,
        uint256 quantity,
        string memory comment
    ) internal returns (uint256 tokenId) {
        // Get the sales config
        SalesConfig storage config = salesConfigs[target];
        uint256 totalPrice = config.pricePerToken * quantity;

        // If sales config does not exist this first check will always fail.
        // Check sale end
        if (block.timestamp > config.saleEnd) {
            revert SaleEnded();
        }

        // Check sale start
        if (block.timestamp < config.saleStart) {
            revert SaleHasNotStarted();
        }

        // Check USDC approval amount
        if (
            totalPrice >
            IERC20(config.erc20Address).allowance(msg.sender, address(this))
        ) {
            revert WrongValueSent();
        }

        // Check minted per address limit
        if (config.maxTokensPerAddress > 0) {
            _requireMintNotOverLimitAndUpdate(
                config.maxTokensPerAddress,
                quantity,
                target,
                tokenId,
                mintTo
            );
        }

        // Mint the token
        tokenId = ICrowdmuseProduct(target).buyPrepaidNFT(
            mintTo,
            garmentType,
            quantity
        );

        // Emit comment event
        if (bytes(comment).length > 0) {
            emit MintComment(mintTo, target, tokenId, quantity, comment);
        }

        // Transfer USDC to escrow
        IERC20(config.erc20Address).transferFrom(
            msg.sender,
            address(this),
            totalPrice
        );

        // Track escrow funds for product
        unchecked {
            if (target != address(0)) {
                balanceOf[target] += totalPrice;
            }
        }

        // Emit escrow event
        emit EscrowDeposit(target, msg.sender, totalPrice);
    }

    /// @notice Sets the sale config for a given token
    /// @param target The target contract for which the sale config is being set
    /// @param salesConfig The sales configuration
    function setSale(
        address target,
        SalesConfig memory salesConfig
    ) external onlyOwner(target) {
        salesConfigs[target] = salesConfig;

        // Emit event
        emit SaleSet(target, salesConfig);
    }

    /// @notice Returns the sale config for a given token
    function sale(
        address tokenContract
    ) external view returns (SalesConfig memory) {
        return salesConfigs[tokenContract];
    }

    modifier onlyOwner(address target) {
        if (Ownable(target).owner() != msg.sender) {
            revert Ownable.OwnableUnauthorizedAccount(msg.sender);
        }

        _;
    }

    // TODO: add method for redeeming escrowed funds
    function redeem(address target) external onlyOwner(target) {
        SalesConfig storage config = salesConfigs[target];

        uint256 amount = balanceOf[target];
        balanceOf[target] = 0;

        IERC20(salesConfigs[target].erc20Address).transfer(
            config.fundsRecipient,
            amount
        );

        emit EscrowRedeemed(
            target,
            config.fundsRecipient,
            salesConfigs[target].erc20Address,
            amount
        );
    }
    // TODO: add method for refunding escrowed funds
}
