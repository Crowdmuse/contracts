// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ILimitedMintPerAddress} from "../interfaces/ILimitedMintPerAddress.sol";

contract LimitedMintPerAddress is ILimitedMintPerAddress {
    /// @notice Storage for slot to check user mints
    /// @notice target contract -> minter user -> numberMinted
    /// @dev No gap or stroage interface since this is used within non-upgradeable contracts
    mapping(address => mapping(address => uint256)) internal mintedPerAddress;

    function getMintedPerWallet(
        address tokenContract,
        address wallet
    ) external view returns (uint256) {
        return mintedPerAddress[tokenContract][wallet];
    }

    function _requireMintNotOverLimitAndUpdate(
        uint256 limit,
        uint256 numRequestedMint,
        address tokenContract,
        address wallet
    ) internal {
        mintedPerAddress[tokenContract][wallet] += numRequestedMint;
        if (mintedPerAddress[tokenContract][wallet] > limit) {
            revert UserExceedsMintLimit(
                wallet,
                limit,
                mintedPerAddress[tokenContract][wallet]
            );
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public pure virtual override returns (bool) {
        return interfaceId == type(ILimitedMintPerAddress).interfaceId;
    }
}
