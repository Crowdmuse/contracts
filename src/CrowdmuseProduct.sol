// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {IERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721A} from "erc721a/contracts/ERC721A.sol";

contract CrowdmuseProduct is ERC721A, ERC2981, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 internal taskId;
    uint256 public tokenId;

    ProductStatus public productStatus; // whether product is complete
    uint256 public buyNFTPrice; // nft price
    uint256 private maxAmountOfTokensPerMint;
    uint256 public contributorTotalSupply; // total supply of tokens for this project
    uint256 public contributorPointsAllocated; // used to ensure that the maximum supply of tokens is not exceeded
    uint256 public contributorPointsComplete; // used to distribute profits
    uint256 public garmentsAvailable; // remaining NFTs
    IERC20 public paymentToken; // ERC20 token address used for payment
    string public baseURI;
    address public admin;

    enum ProductStatus {
        InProgress,
        Complete
    }

    enum NFTTypes {
        Default,
        Product,
        Contributor,
        Investor
    }

    enum TaskStatus {
        Open,
        Assigned,
        Complete
    }

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

    struct Task {
        uint256[] contributionValues;
        address[] taskContributors;
        TaskStatus[] taskStatus;
        uint256[] taskContributorTypes;
    }

    struct Inventory {
        string keyName;
        uint96 garmentsRemaining;
    }

    mapping(uint256 => TaskInformation) public taskByTaskId;
    mapping(uint256 => uint8) public NFTByType; // mapping that keeps the NFT type for each  NFT id
    mapping(uint256 => bytes32) public NFTBySize; // mapping that keeps the NFT type for each  NFT id
    mapping(address => bool) public contributors;

    // Variables for managing inventory //
    string public inventoryKey;
    string[] public garmentTypes; // This is the format of the garmentTypes '{inventoryKey}:Green,size:large'
    uint96 public numberGarmentTypes;
    mapping(bytes32 => uint96) public inventoryGarmentsRemaining;
    mapping(bytes32 => uint96) public inventoryGarmentsOrdered;
    bool public madeToOrder;

    struct Token {
        string productName;
        string productSymbol;
        string baseUri;
        uint256 maxAmountOfTokensPerMint;
    }

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

        madeToOrder = _madeToOrder;
        if (!madeToOrder) {
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
        }

        if (bytes(_token.baseUri).length > 0) baseURI = _token.baseUri;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only Admin");
        _;
    }

    function changeAdmin(address _newAddress) public onlyOwner {
        require(_newAddress != address(0), "Zero Address");
        admin = _newAddress;
    }

    fallback() external payable {}

    receive() external payable {}

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

    function submitProduct(uint256 _buyNFTPrice) public onlyOwner {
        require(productStatus != ProductStatus.Complete, "already submitted");
        productStatus = ProductStatus.Complete;
        buyNFTPrice = _buyNFTPrice;
    }

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

    function addContributor(address to) private {
        contributors[to] = true;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function changeBaseUri(string memory _newBaseUri) external onlyOwner {
        // In case the gateway breaks
        baseURI = _newBaseUri;
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function tokenURI(
        uint256 _tokenId
    ) public view override(ERC721A) returns (string memory) {
        return baseURI;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721A, ERC2981) returns (bool) {
        return (interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId));
    }

    function getMaxAmountOfTokensPerMint() public view returns (uint256) {
        return maxAmountOfTokensPerMint;
    }
}
