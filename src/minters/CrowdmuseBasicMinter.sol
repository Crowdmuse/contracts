// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMinterErrors} from "../interfaces/IMinterErrors.sol";
import {ICrowdmuseProduct} from "../interfaces/ICrowdmuseProduct.sol";

/// @title CrowdmuseBasicMinter
/// @notice A minter that allows for basic purchasing on Crowdmuse
contract CrowdmuseBasicMinter is IMinterErrors {
    function contractURI() external pure returns (string memory) {
        return "https://github.com/Crowdmuse/contracts";
    }

    /// @notice The name of the minter
    function contractName() external pure returns (string memory) {
        return "Crowdmuse Basic Minter";
    }

    /// @notice The version of the minter
    function contractVersion() external pure returns (string memory) {
        return "0.0.1";
    }

    event MintComment(
        address indexed sender,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 quantity,
        string comment
    );

    /// @notice mint .
    function mint(
        address target,
        address mintTo,
        bytes32 garmentType,
        uint256 quantity,
        string memory comment
    ) external returns (uint256 tokenId) {
        tokenId = _requestMint(target, mintTo, garmentType, quantity, comment);
    }

    /// @notice mint.
    function _requestMint(
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
}
