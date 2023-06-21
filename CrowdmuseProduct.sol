// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/common/ERC2981.sol";
import { ERC721URIStorage } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import { ERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CrowdmuseProduct is ERC721, ERC721URIStorage, ERC721Enumerable, ERC2981, ReentrancyGuard, Ownable {

  using SafeMath for uint256;
  using Counters for Counters.Counter;
  using SafeERC20 for IERC20;

  Counters.Counter internal taskId;
  Counters.Counter internal contributionId;
  Counters.Counter public tokenId;

  uint256 public projectSource; // project Id that this product belongs to

  ProductStatus public productStatus; // whether product is complete
  uint256 public buyNFTPrice; // buy nft price
  uint256 public contributorTotalSupply; // total supply of tokens for this project
  uint256 public contributorPointsAllocated; // used to ensure that the maximum supply of tokens is not exceeded
  uint256 public contributorPointsComplete; // used to distribute profits
  uint256 public garmentsAvailable; // remaining NFTs
  IERC20 public paymentToken; // ERC20 token address used for payment
  string public baseURI;

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


  mapping(uint256 => TaskInformation) public taskByTaskId;
  mapping(uint256 => uint8) public NFTByType; /// mapping that keeps the NFT type for each  NFT id
  mapping(address => bool) public contributors;

  constructor(
    uint96 _feeNumerator,
    uint256 _contributorTotalSupply,
    uint256 _garmentsAvailable,
    Task memory _task,
    string memory _productName,
    string memory _productSymbol,
    string memory _baseUri,
    address _paymentTokenAddress
  ) ERC721(_productName, _productSymbol) {
    _setDefaultRoyalty(address(this), _feeNumerator);
    paymentToken = IERC20(_paymentTokenAddress);
    productStatus = ProductStatus.InProgress;
    contributorTotalSupply = _contributorTotalSupply;
    garmentsAvailable = _garmentsAvailable;
    createTasks(_task.contributionValues, _task.taskContributors, _task.taskStatus, _task.taskContributorTypes);

    if (bytes(_baseUri).length > 0) baseURI = _baseUri;
  }


  function addContributor(address to) private {
    contributors[to] = true;
  }

  function createTasks(
    uint256[] memory _contributionValues,
    address[] memory _taskContributors,
    TaskStatus[] memory _taskStatus,
    uint256[] memory _taskType
  ) public onlyOwner {
    for (uint256 i = 0; i < _contributionValues.length; i++) {
      require(
        _contributionValues[i] + contributorPointsAllocated <= contributorTotalSupply,
        "Contribution value exceeds limit"
      );
      taskId.increment();
      uint256 _taskId = taskId.current();
     TaskInformation storage _taskByTaskId = taskByTaskId[_taskId];
      _taskByTaskId.taskId = _taskId;
      _taskByTaskId.taskOwnerAddress = msg.sender;
      _taskByTaskId.contributionValue = _contributionValues[i];
      _taskByTaskId.taskStatus = _taskStatus[i];
      _taskByTaskId.taskContributor = _taskContributors[i];
      _taskByTaskId.taskType = _taskType[i];
      contributorPointsAllocated += _contributionValues[i];
      if (_taskStatus[i] == TaskStatus.Complete) {
        // approve
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
    createTasks(_contributionValues, _taskContributors, _taskStatus, _taskType);
    submitProduct(_buyNFTPrice);
  }

  function buyNFT(address _to) public nonReentrant returns (uint256 _tokenId) {
    require(productStatus == ProductStatus.Complete, "Product not complete");
    require(paymentToken.balanceOf(msg.sender) >= buyNFTPrice, "Not enough balance");
    require(garmentsAvailable > 0, "No garments left");
    require(_to != address(0), "Address must not be zero");
    if (buyNFTPrice > 0) {
      paymentToken.safeTransferFrom(msg.sender, address(this), buyNFTPrice);
    }
    tokenId.increment();
    _tokenId = tokenId.current();
    _safeMint(_to, _tokenId);
    garmentsAvailable -= 1;
    uint8 productTypeAsUint = uint8(NFTTypes.Product);
    NFTByType[_tokenId] = productTypeAsUint;
  }

  function distributeRewards() public nonReentrant {
    uint256 currentBalance = paymentToken.balanceOf(address(this));
    require(currentBalance > 0, "No funds available");

    for (uint256 i = 1; i <= taskId.current(); i++) {
      if (taskByTaskId[i].taskStatus == TaskStatus.Complete) {
        uint256 amountToSend = currentBalance
          .mul(taskByTaskId[i].contributionValue)
          .mul(10000)
          .div(contributorPointsComplete)
          .div(10000); //This means that if  the person has less than 0.01% of the total tokens, they wont be eligible for a return
          paymentToken.safeTransfer(taskByTaskId[i].taskContributor, amountToSend);
      }
    }
  }

  function _baseURI() internal view override returns (string memory) {
    return baseURI;
  }

  function changeBaseUri(string memory _newBaseUri) external onlyOwner {
    // In case the gateway breaks
    baseURI = _newBaseUri;
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId,
    uint256 batchSize
  ) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId, batchSize);
  }

  function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
    super._burn(tokenId);
  }

  function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
    return baseURI;
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721URIStorage,ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}