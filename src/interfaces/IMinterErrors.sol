// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IMinterErrors {
    error SaleEnded();
    error SaleHasNotStarted();
    error WrongValueSent();
    error InvalidMerkleProof(
        address mintTo,
        bytes32[] merkleProof,
        bytes32 merkleRoot
    );
}
