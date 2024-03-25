// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMinterErrors} from "../interfaces/IMinterErrors.sol";

/// @title CrowdmuseBasicMinter
/// @notice A sale strategy that allows for basic minting on Crowdmuse
contract CrowdmuseBasicMinter is IMinterErrors {
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

    constructor(address _protocolFeeRecipient) {
        protocolFeeRecipient = _protocolFeeRecipient;
    }

    // target -> tokenId -> settings
    mapping(address => mapping(uint256 => SalesConfig)) internal salesConfigs;
    // protocol fee recipient
    address public protocolFeeRecipient;

    function contractURI() external pure returns (string memory) {
        return "https://github.com/Crowdmuse/contracts";
    }

    /// @notice The name of the sale strategy
    function contractName() external pure returns (string memory) {
        return "Crowdmuse Basic Minter";
    }

    /// @notice The version of the sale strategy
    function contractVersion() external pure returns (string memory) {
        return "0.0.1";
    }

    event SaleSet(
        address indexed mediaContract,
        uint256 indexed tokenId,
        SalesConfig salesConfig
    );
    event MintComment(
        address indexed sender,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 quantity,
        string comment
    );

    /// @notice mint using ERC20 calls.
    /// @param target The target drop
    /// @param tokenId The token ID to mint
    /// @param quantity The quantity of tokens to mint
    /// @param minterArguments The arguments passed to the minter, which should be the address to mint to
    function requestMint(
        address target,
        uint256 tokenId,
        uint256 quantity,
        uint256,
        bytes calldata minterArguments
    ) external {
        _requestMint(target, tokenId, quantity, 0, minterArguments);
    }

    /// @notice Mint batch function that 1) checks quantity and 2) keeps track of allowed tokens
    /// @param targets target drops
    /// @param ids token ids to mint
    /// @param quantities of tokens to mint
    /// @param minterArguments as specified by 1155 standard
    function requestMintBatch(
        address[] memory targets,
        uint256[] memory ids,
        uint256[] memory quantities,
        bytes[] calldata minterArguments
    ) external {
        uint256 numTokens = ids.length;

        for (uint256 i; i < numTokens; ++i) {
            _requestMint(
                targets[i],
                ids[i],
                quantities[i],
                0,
                minterArguments[i]
            );
        }
    }

    /// @notice mint using ERC20 calls.
    /// @param target The target drop
    /// @param tokenId The token ID to mint
    /// @param quantity The quantity of tokens to mint
    /// @param minterArguments The arguments passed to the minter, which should be the address to mint to
    function _requestMint(
        address target,
        uint256 tokenId,
        uint256 quantity,
        uint256,
        bytes calldata minterArguments
    ) internal {
        address mintTo;
        string memory comment = "";
        if (minterArguments.length == 32) {
            mintTo = abi.decode(minterArguments, (address));
        } else {
            (mintTo, comment) = abi.decode(minterArguments, (address, string));
        }

        SalesConfig storage config = salesConfigs[target][tokenId];
        uint256 totalPrice = config.pricePerToken * quantity;

        // If sales config does not exist this first check will always fail.

        // Check sale end
        if (block.timestamp > config.saleEnd) {
            revert SaleEnded();
        }

        // Check sale start
        if (block.timestamp < config.saleStart) {
            revert SaleHasNotStarted();
        }

        // Check USDC approval amount
        if (
            totalPrice >
            IERC20(config.erc20Address).allowance(msg.sender, address(this))
        ) {
            revert WrongValueSent();
        }

        // Check minted per address limit
        if (config.maxTokensPerAddress > 0) {
            // _requireMintNotOverLimitAndUpdate(
            //     config.maxTokensPerAddress,
            //     quantity,
            //     target,
            //     tokenId,
            //     mintTo
            // );
        }

        bool shouldTransferFunds = config.fundsRecipient != address(0);

        // // Mint command
        // IZoraCreator1155(target).adminMint(
        //     mintTo,
        //     tokenId,
        //     quantity,
        //     bytes("")
        // );

        if (bytes(comment).length > 0) {
            emit MintComment(mintTo, target, tokenId, quantity, comment);
        }

        uint256 protocolFee = totalPrice / 20;
        uint256 creatorFee = totalPrice - protocolFee;
        // transfer 5% protocol fee
        IERC20(config.erc20Address).transferFrom(
            msg.sender,
            protocolFeeRecipient,
            protocolFee
        );

        // Should transfer funds if funds recipient is set to a non-default address
        if (shouldTransferFunds) {
            IERC20(config.erc20Address).transferFrom(
                msg.sender,
                config.fundsRecipient,
                creatorFee
            );
        }
    }

    /// @notice Sets the sale config for a given token
    function setSale(uint256 tokenId, SalesConfig memory salesConfig) external {
        salesConfigs[msg.sender][tokenId] = salesConfig;

        // Emit event
        emit SaleSet(msg.sender, tokenId, salesConfig);
    }

    /// @notice Deletes the sale config for a given token
    function resetSale(uint256 tokenId) external {
        delete salesConfigs[msg.sender][tokenId];

        // Deleted sale emit event
        emit SaleSet(msg.sender, tokenId, salesConfigs[msg.sender][tokenId]);
    }

    /// @notice Returns the sale config for a given token
    function sale(
        address tokenContract,
        uint256 tokenId
    ) external view returns (SalesConfig memory) {
        return salesConfigs[tokenContract][tokenId];
    }

    /**
     * @dev Sets the recipient of the protocol fee.
     *
     * This function allows the current protocolFeeRecipient to set the recipient of the protocol fee.
     * The protocol fee is a percentage of each transaction that is sent to this address.
     *
     * Requirements:
     *
     * - The caller must be the protocolFeeRecipient.
     *
     * @param _protocolFeeRecipient The address of the protocol fee recipient.
     */
    function setProtocolFeeRecipient(address _protocolFeeRecipient) external {
        require(
            msg.sender == protocolFeeRecipient,
            "Not protocol fee recipient"
        );
        protocolFeeRecipient = _protocolFeeRecipient;
    }
}
