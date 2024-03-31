// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ICrowdmuseEscrow {
    /// @notice Escrow Deposit Event
    /// @param target collection for escrow
    /// @param from The caller of the deposit
    /// @param escrowAmount Creator reward amount
    event EscrowDeposit(
        address indexed target,
        address indexed from,
        uint256 escrowAmount
    );

    event EscrowRedeemed(
        address indexed product,
        address indexed fundsRecipient,
        address indexed erc20Address,
        uint256 amount
    );
}
