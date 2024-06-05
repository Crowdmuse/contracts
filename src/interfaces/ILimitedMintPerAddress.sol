// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

interface ILimitedMintPerAddressErrors {
    error UserExceedsMintLimit(
        address user,
        uint256 limit,
        uint256 requestedAmount
    );
}

interface ILimitedMintPerAddress is IERC165, ILimitedMintPerAddressErrors {
    function getMintedPerWallet(
        address token,
        address wallet
    ) external view returns (uint256);
}
