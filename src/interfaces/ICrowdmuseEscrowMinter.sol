// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/// @title ICrowdmuseEscrowMinter
/// @notice Interface for Crowdmuse Escrow Minter functionality
interface ICrowdmuseEscrowMinter {
    /// @dev Error thrown when an operation that requires the escrow balance to be zero is attempted, but the escrow balance is not zero.
    error EscrowBalanceNotZero();

    /// @dev Error thrown when an operation that requires a non-zero price for escrow is attempted with a zero price.
    error EscrowPriceZero();

    /// @dev Error thrown when an operation that requires the escrow to not exist is attempted, but the escrow already exists.
    error EscrowAlreadyExists();

    /// @dev Error thrown when an operation that requires the escrow to exist beyond saleEnd is attempted, but the time is still before saleEnd.
    error EscrowNotEnded();

    /// @dev Error thrown when an operation that requires the caller be an escrow tokens owner is attempted, but the msg.sender is not a token owner.
    error EscrowNotTokenOwner();

    /// @notice Escrow Deposit Event
    /// @param target collection for escrow
    /// @param from The caller of the deposit
    /// @param escrowAmount Creator reward amount
    event EscrowDeposit(
        address indexed target,
        address indexed from,
        uint256 escrowAmount
    );

    /// @notice Emitted when escrowed funds for a product are successfully redeemed.
    /// @dev Tracks the redemption of escrow funds, indicating the movement of funds from escrow to the recipient.
    /// @param product The address of the product contract whose escrow funds were redeemed.
    /// @param fundsRecipient The address of the recipient who received the escrowed funds.
    /// @param erc20Address The address of the ERC20 token in which the escrowed funds were held.
    /// @param totalRedeemed The amount of funds that were redeemed from escrow.
    event EscrowRedeemed(
        address indexed product,
        address indexed fundsRecipient,
        address indexed erc20Address,
        uint256 totalRedeemed
    );

    /// @notice Emitted when escrowed funds for a product are successfully redeemed.
    /// @dev Tracks the redemption of escrow funds, indicating the movement of funds from escrow to the recipient.
    /// @param product The address of the product contract whose escrow funds were redeemed.
    /// @param erc20Address The address of the ERC20 token in which the escrowed funds were held.
    /// @param totalRefunded The amount of funds that were refunded from escrow.
    event EscrowRefunded(
        address indexed product,
        address indexed erc20Address,
        uint256 totalRefunded
    );

    enum MinimumEscrowDuration {
        Days15,
        Days30,
        Days60,
        Days90
    }
}
