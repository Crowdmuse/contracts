// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICrowdmuseProduct {
    /// @notice Enumeration for task statuses
    enum TaskStatus {
        Open,
        Assigned,
        Complete
    }

    /// @notice Structure for defining tasks within a project
    /// @param contributionValues The value of contributions for the task
    /// @param taskContributors Addresses of contributors to the task
    /// @param taskStatus Current status of each task
    /// @param taskContributorTypes Types of contributors for the task
    struct Task {
        uint256[] contributionValues;
        address[] taskContributors;
        TaskStatus[] taskStatus;
        uint256[] taskContributorTypes;
    }

    /// @notice Structure for defining token metadata and minting configurations
    /// @param productName Name of the product or NFT collection
    /// @param productSymbol Symbol of the NFT collection
    /// @param baseUri Base URI for NFT metadata
    /// @param maxAmountOfTokensPerMint Maximum number of tokens that can be minted in one transaction
    struct Token {
        string productName;
        string productSymbol;
        string baseUri;
        uint256 maxAmountOfTokensPerMint;
    }

    /// @notice Structure for managing inventory of a product
    /// @param keyName Unique key for inventory item
    /// @param garmentsRemaining Number of items remaining in this inventory category
    struct Inventory {
        string keyName;
        uint96 garmentsRemaining;
    }

    /// @notice Enumeration for the status of the product
    enum ProductStatus {
        InProgress,
        Complete
    }

    /// @notice Enumeration for types of NFTs that can be minted
    enum NFTTypes {
        Default,
        Product,
        Contributor,
        Investor
    }

    /// @notice Detailed information about a task within the project
    /// @param taskId Unique identifier for the task
    /// @param contributionValue Value of the contribution towards the task
    /// @param taskOwnerAddress Address of the task owner
    /// @param taskContributor Address of the task contributor
    /// @param licensedProjects Array of project identifiers this task is licensed for
    /// @param feedbackScore Score given as feedback for the task completion
    /// @param submissionUri URI for the task submission details
    /// @param taskMetadataUri URI for metadata related to the task
    /// @param taskStatus Current status of the task
    /// @param taskType Numerical type of the task
    struct TaskInformation {
        uint256 taskId;
        uint256 contributionValue;
        address taskOwnerAddress;
        address taskContributor;
        uint256[] licensedProjects;
        uint24 feedbackScore;
        string submissionUri;
        string taskMetadataUri;
        TaskStatus taskStatus;
        uint256 taskType;
    }

    /// @notice Allows the admin to mint NFTs for a specific garment type and quantity without payment
    /// @dev Used for promotional or administrative purposes
    /// @param _to Recipient of the NFTs
    /// @param garmentType Type of garment (NFT) being minted
    /// @param _quantity Quantity of NFTs to mint
    /// @return _tokenId The ID of the last token minted
    function buyPrepaidNFT(
        address _to,
        bytes32 garmentType,
        uint256 _quantity
    ) external returns (uint256);

    /// @notice Returns the maximum number of tokens that can be minted in a single operation
    /// @return The maximum number of tokens per mint
    function getMaxAmountOfTokensPerMint() external view returns (uint256);

    /// @notice Returns the maximum number of tokens that can be minted in a single operation
    function buyNFTPrice() external view returns (uint256);

    /// ERC20 token used for payment
    function paymentToken() external view returns (IERC20);
}
