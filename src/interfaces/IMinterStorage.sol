// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IMinterStorage {
    struct SalesConfig {
        /// @notice Unix timestamp for the sale start
        uint64 saleStart;
        /// @notice Unix timestamp for the sale end
        uint64 saleEnd;
        /// @notice Max tokens that can be minted for an address, 0 if unlimited
        uint64 maxTokensPerAddress;
        /// @notice Price per token in ERC20 amount.
        uint96 pricePerToken;
        /// @notice Funds recipient (0 if no different funds recipient than the contract global)
        address fundsRecipient;
        /// @notice ERC20 address
        address erc20Address;
    }

    event SaleSet(address indexed mediaContract, SalesConfig salesConfig);
}
