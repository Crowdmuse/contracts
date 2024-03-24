// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {IERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721A} from "erc721a/contracts/ERC721A.sol";
import {ICrowdmuseProduct} from "./interfaces/ICrowdmuseProduct.sol";

/// @title CrowdmuseProduct
/// @notice This contract manages the lifecycle of a product in the Crowdmuse ecosystem, handling tasks, inventory, and NFT minting.
contract CrowdmuseProduct is
    ICrowdmuseProduct,
    ERC721A,
    ERC2981,
    ReentrancyGuard,
    Ownable
{
    using SafeERC20 for IERC20;

    /// @dev Internal counter for task IDs
    uint256 internal taskId;
    /// @dev Public counter for token IDs
    uint256 public tokenId;
    /// Current status of the product, indicating if it is in progress or complete
    ProductStatus public productStatus;
    /// Price for buying an NFT
    uint256 public buyNFTPrice;
    /// Maximum amount of tokens that can be minted in a single operation
    uint256 private maxAmountOfTokensPerMint;
    /// Total supply of tokens for this project
    uint256 public contributorTotalSupply;
    /// Total amount of contribution points allocated
    uint256 public contributorPointsAllocated;
    /// Total amount of contribution points that have been completed
    uint256 public contributorPointsComplete;
    /// Remaining garments (NFTs) available for purchase
    uint256 public garmentsAvailable;
    /// ERC20 token used for payment
    IERC20 public paymentToken;
    /// Base URI for the NFT metadata
    string public baseURI;
    /// Administrator address with special permissions
    address public admin;
    /// Mapping of task ID to its information
    mapping(uint256 => TaskInformation) public taskByTaskId;
    /// Mapping of NFT ID to its type
    mapping(uint256 => uint8) public NFTByType;
    /// Mapping of NFT ID to its size
    mapping(uint256 => bytes32) public NFTBySize;
    /// Mapping to track which addresses are contributors
    mapping(address => bool) public contributors;
    /// Key for managing inventory
    string public inventoryKey;
    /// List of garment types available
    string[] public garmentTypes;
    /// Number of garment types
    uint96 public numberGarmentTypes;
    /// Mapping of garment type to remaining garments
    mapping(bytes32 => uint96) public inventoryGarmentsRemaining;
    /// Mapping of garment type to ordered garments
    mapping(bytes32 => uint96) public inventoryGarmentsOrdered;
    /// Indicates if the product is made to order
    bool public madeToOrder;

    /// @notice Contract constructor that initializes the Crowdmuse product
    /// @param _feeNumerator Royalty fee numerator for the ERC2981 standard
    /// @param _contributorTotalSupply Total supply of contribution points for this project
    /// @param _garmentsAvailable Number of NFTs available for this project
    /// @param _task Initial task information
    /// @param _token Token details like name, symbol, and base URI
    /// @param _paymentTokenAddress Address of the ERC20 token used for payments
    /// @param _inventoryKey Unique key for managing inventory
    /// @param _inventory Initial inventory setup
    /// @param _madeToOrder Boolean indicating if the product is made to order
    /// @param _admin Address of the administrator
    /// @param _buyNFTPrice Price for buying an NFT
    constructor(
        uint96 _feeNumerator,
        uint256 _contributorTotalSupply,
        uint256 _garmentsAvailable,
        Task memory _task,
        Token memory _token,
        address _paymentTokenAddress,
        string memory _inventoryKey,
        Inventory[] memory _inventory,
        bool _madeToOrder,
        address _admin,
        uint256 _buyNFTPrice
    ) ERC721A(_token.productName, _token.productSymbol) Ownable(_admin) {
        admin = address(_admin);
        _setDefaultRoyalty(address(this), _feeNumerator);
        paymentToken = IERC20(_paymentTokenAddress);
        productStatus = ProductStatus.InProgress;
        contributorTotalSupply = _contributorTotalSupply;
        garmentsAvailable = _garmentsAvailable;
        maxAmountOfTokensPerMint = _token.maxAmountOfTokensPerMint;
        createTasks(
            _task.contributionValues,
            _task.taskContributors,
            _task.taskStatus,
            _task.taskContributorTypes
        );
        buyNFTPrice = _buyNFTPrice;
        if (buyNFTPrice > 0) {
            productStatus = ProductStatus.Complete;
        }

        if (!_madeToOrder) {
            uint96 totalGarmentsMatches;
            inventoryKey = _inventoryKey;
            for (uint256 i = 0; i < _inventory.length; i++) {
                totalGarmentsMatches += _inventory[i].garmentsRemaining;
                garmentTypes.push(_inventory[i].keyName);
                inventoryGarmentsRemaining[
                    keccak256(abi.encodePacked(_inventory[i].keyName))
                ] = _inventory[i].garmentsRemaining;
                numberGarmentTypes = uint96(_inventory.length);
            }
            require(
                totalGarmentsMatches == uint96(_garmentsAvailable),
                "garment numbers not matching"
            );
        } else {
            madeToOrder = true;
        }

        if (bytes(_token.baseUri).length > 0) baseURI = _token.baseUri;
    }

    /// @notice Modifier that allows only the admin to perform certain actions
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only Admin");
        _;
    }

    /// @notice Allows the owner to change the admin address
    /// @param _newAddress The new admin address
    function changeAdmin(address _newAddress) public onlyOwner {
        require(_newAddress != address(0), "Zero Address");
        admin = _newAddress;
    }

    fallback() external payable {}

    receive() external payable {}

    /// @notice Creates tasks for the product
    /// @dev Only callable by the owner
    /// @param _contributionValues Array of contribution values for each task
    /// @param _taskContributors Array of addresses for task contributors
    /// @param _taskStatus Array of task statuses
    /// @param _taskType Array of task types
    function createTasks(
        uint256[] memory _contributionValues,
        address[] memory _taskContributors,
        TaskStatus[] memory _taskStatus,
        uint256[] memory _taskType
    ) public onlyOwner {
        for (uint256 i = 0; i < _contributionValues.length; i++) {
            require(
                _contributionValues[i] + contributorPointsAllocated <=
                    contributorTotalSupply,
                "Contribution value exceeds limit"
            );
            taskId += 1;
            uint256 _taskId = taskId;
            TaskInformation storage _taskByTaskId = taskByTaskId[_taskId];
            _taskByTaskId.taskId = _taskId;
            _taskByTaskId.taskOwnerAddress = msg.sender;
            _taskByTaskId.contributionValue = _contributionValues[i];
            _taskByTaskId.taskStatus = _taskStatus[i];
            _taskByTaskId.taskContributor = _taskContributors[i];
            _taskByTaskId.taskType = _taskType[i];
            contributorPointsAllocated += _contributionValues[i];
            if (_taskStatus[i] == TaskStatus.Complete) {
                contributorPointsComplete += _contributionValues[i];
                addContributor(_taskContributors[i]);
            }
        }
    }

    /// @notice Submits the product, marking it as complete and setting the buy NFT price
    /// @dev Only callable by the owner
    /// @param _buyNFTPrice The price for buying an NFT
    function submitProduct(uint256 _buyNFTPrice) public onlyOwner {
        require(productStatus != ProductStatus.Complete, "already submitted");
        productStatus = ProductStatus.Complete;
        buyNFTPrice = _buyNFTPrice;
    }

    /// @notice Allows the creation of tasks and submission of the product in one transaction
    /// @dev Only callable by the owner
    /// @param _contributionValues Array of contribution values for the tasks
    /// @param _taskContributors Array of contributor addresses for the tasks
    /// @param _taskStatus Array of status values for each task
    /// @param _taskType Array of task types
    /// @param _buyNFTPrice The price for buying an NFT once the product is submitted
    function createTasksAndSubmitProduct(
        uint256[] memory _contributionValues,
        address[] memory _taskContributors,
        TaskStatus[] memory _taskStatus,
        uint256[] memory _taskType,
        uint256 _buyNFTPrice
    ) public onlyOwner {
        createTasks(
            _contributionValues,
            _taskContributors,
            _taskStatus,
            _taskType
        );
        submitProduct(_buyNFTPrice);
    }

    /// @notice Buys an NFT of a specific garment type and quantity if the product is complete
    /// @dev Ensures the caller has enough payment token balance and approves the contract to spend it
    /// @param _to Recipient of the NFT
    /// @param garmentType Type of garment (NFT) being purchased
    /// @param _quantity Quantity of NFTs to buy
    /// @return _tokenId The ID of the last token minted as part of the purchase
    function buyNFT(
        address _to,
        bytes32 garmentType,
        uint256 _quantity
    ) public nonReentrant returns (uint256 _tokenId) {
        require(_to != address(0), "Address must not be zero");
        require(
            productStatus == ProductStatus.Complete,
            "Product not complete"
        );
        require(
            _quantity <= maxAmountOfTokensPerMint,
            "Quantity exceeds limit"
        );
        require(garmentsAvailable >= _quantity, "No garments left");
        require(
            inventoryGarmentsRemaining[garmentType] >= _quantity,
            "None of this type remaining"
        );
        uint256 transferAmount = buyNFTPrice * _quantity;

        require(
            paymentToken.balanceOf(msg.sender) >= transferAmount,
            "Not enough balance"
        );
        if (buyNFTPrice > 0) {
            paymentToken.safeTransferFrom(
                msg.sender,
                address(this),
                transferAmount
            );
        }

        _safeMint(_to, _quantity);
        if (madeToOrder) {
            inventoryGarmentsOrdered[garmentType] += uint96(_quantity);
        } else {
            inventoryGarmentsRemaining[garmentType] -= uint96(_quantity);
        }
        garmentsAvailable -= _quantity;
        uint8 productTypeAsUint = uint8(NFTTypes.Product);

        NFTByType[_tokenId] = productTypeAsUint;
        for (uint256 i = 1; i <= _quantity; i++) {
            tokenId += 1;
            _tokenId = tokenId;
            NFTBySize[_tokenId] = garmentType;
        }
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
    ) public nonReentrant onlyAdmin returns (uint256 _tokenId) {
        require(_to != address(0), "Address must not be zero");
        require(
            productStatus == ProductStatus.Complete,
            "Product not complete"
        );
        require(
            _quantity <= maxAmountOfTokensPerMint,
            "Quantity exceeds limit"
        );
        require(garmentsAvailable >= _quantity, "No garments left");
        require(
            inventoryGarmentsRemaining[garmentType] >= _quantity,
            "None of this type remaining"
        );
        _safeMint(_to, _quantity);
        if (madeToOrder) {
            inventoryGarmentsOrdered[garmentType] += uint96(_quantity);
        } else {
            inventoryGarmentsRemaining[garmentType] -= uint96(_quantity);
        }
        garmentsAvailable -= _quantity;
        uint8 productTypeAsUint = uint8(NFTTypes.Product);
        NFTByType[_tokenId] = productTypeAsUint;
        for (uint256 i = 1; i <= _quantity; i++) {
            tokenId += 1;
            _tokenId = tokenId;
            NFTBySize[_tokenId] = garmentType;
        }
    }

    /// @notice Distributes rewards to contributors based on their contribution values
    /// @dev Can be called by anyone after the product is complete to distribute ERC20 token rewards
    function distributeRewards() public nonReentrant {
        uint256 currentBalance = paymentToken.balanceOf(address(this));
        require(currentBalance > 0, "No funds available");

        for (uint256 i = 1; i <= taskId; i++) {
            if (taskByTaskId[i].taskStatus == TaskStatus.Complete) {
                uint256 numerator = currentBalance *
                    (taskByTaskId[i].contributionValue) *
                    (10000);
                uint256 denominator = (contributorPointsComplete * 10000);
                uint256 amountToSend = numerator / denominator; //This means that if  the person has less than 0.01% of the total tokens, they wont be eligible for a return
                paymentToken.safeTransfer(
                    taskByTaskId[i].taskContributor,
                    amountToSend
                );
            }
        }
    }

    /// @notice Distributes native currency rewards to contributors based on their contribution values
    /// @dev Can be called by anyone after the product is complete to distribute native currency rewards
    function distributeRewardsNative() public nonReentrant {
        uint256 currentBalance = address(this).balance;
        require(currentBalance > 0, "No funds available");

        for (uint256 i = 1; i <= taskId; i++) {
            if (taskByTaskId[i].taskStatus == TaskStatus.Complete) {
                uint256 numerator = currentBalance *
                    (taskByTaskId[i].contributionValue) *
                    (10000);
                uint256 denominator = (contributorPointsComplete * 10000);

                uint256 amountToSend = numerator / denominator; //This means that if  the person has less than 0.01% of the total tokens, they wont be eligible for a return
                (bool success, ) = taskByTaskId[i].taskContributor.call{
                    value: amountToSend
                }("");
                require(success, "Did not send"); // Make sure this reverts all the sends if one of them fails/ Make sure this reverts all the sends if one of them fails
            }
        }
    }

    /// @notice Adds an address to the list of contributors
    /// @dev Private function called internally to mark addresses as contributors
    /// @param to The address to add as a contributor
    function addContributor(address to) private {
        contributors[to] = true;
    }

    /// @return The overridden base URI set for the NFT metadata
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /// @notice Allows the owner to change the base URI for the NFT metadata
    /// @param _newBaseUri The new base URI to be set
    function changeBaseUri(string memory _newBaseUri) external onlyOwner {
        baseURI = _newBaseUri;
    }

    /// @notice Overrides the ERC721A's _startTokenId function to start token IDs at 1 instead of 0
    /// @return The starting token ID for the NFTs, which is 1
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    /// @notice Returns the token URI for a given token ID
    /// @return The token URI string for the given token ID
    function tokenURI(
        uint256
    ) public view override(ERC721A) returns (string memory) {
        return baseURI;
    }

    /// @notice Checks if the contract supports a given interface
    /// @param interfaceId The interface ID to check for support
    /// @return A boolean value indicating whether the contract supports the given interface
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721A, ERC2981) returns (bool) {
        return (interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId));
    }

    /// @notice Returns the maximum number of tokens that can be minted in a single operation
    /// @return The maximum number of tokens per mint
    function getMaxAmountOfTokensPerMint() public view returns (uint256) {
        return maxAmountOfTokensPerMint;
    }
}
