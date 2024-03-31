// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMinterErrors} from "../interfaces/IMinterErrors.sol";
import {ICrowdmuseProduct} from "../interfaces/ICrowdmuseProduct.sol";
import {IMinterStorage} from "../interfaces/IMinterStorage.sol";

/// @title CrowdmuseEscrowMinter
/// @notice A minter that allows for basic purchasing on Crowdmuse
contract CrowdmuseEscrowMinter is IMinterErrors, IMinterStorage {
    // target -> tokenId -> settings
    mapping(address => mapping(uint256 => SalesConfig)) internal salesConfigs;

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
        tokenId = ICrowdmuseProduct(target).buyPrepaidNFT(
            mintTo,
            garmentType,
            quantity
        );

        if (bytes(comment).length > 0) {
            emit MintComment(mintTo, target, tokenId, quantity, comment);
        }
    }

    /// @notice Sets the sale config for a given token
    function setSale(uint256 tokenId, SalesConfig memory salesConfig) external {
        salesConfigs[msg.sender][tokenId] = salesConfig;

        // Emit event
        emit SaleSet(msg.sender, tokenId, salesConfig);
    }

    /// @notice Returns the sale config for a given token
    function sale(
        address tokenContract,
        uint256 tokenId
    ) external view returns (SalesConfig memory) {
        return salesConfigs[tokenContract][tokenId];
    }
}
