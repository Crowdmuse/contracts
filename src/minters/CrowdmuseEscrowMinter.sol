// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721A} from "erc721a/contracts/IERC721A.sol";
import {SplitsV2} from "../utils/SplitsV2.sol";
import {LimitedMintPerAddress} from "../utils/LimitedMintPerAddress.sol";
import {IMinterErrors} from "../interfaces/IMinterErrors.sol";
import {ICrowdmuseProduct} from "../interfaces/ICrowdmuseProduct.sol";
import {ICrowdmuseEscrowMinter} from "../interfaces/ICrowdmuseEscrowMinter.sol";
import {IMinterStorage} from "../interfaces/IMinterStorage.sol";

/// @title CrowdmuseEscrowMinter
/// @notice A minter that allows for escrow purchasing on Crowdmuse
contract CrowdmuseEscrowMinter is
    LimitedMintPerAddress,
    ICrowdmuseEscrowMinter,
    IMinterErrors,
    IMinterStorage,
    ReentrancyGuard,
    SplitsV2
{
    // product -> settings
    mapping(address => SalesConfig) internal salesConfigs;
    /// @notice A product's escrow balance
    mapping(address => uint256) public balanceOf;
    /// @notice A contributor's escrow balance for a given target
    mapping(address => mapping(address => uint256)) private contributions;

    constructor(address _pushSplitFactory) SplitsV2(_pushSplitFactory) {}

    /// @notice Retrieves the contract metadata URI
    /// @return A string representing the metadata URI for this contract
    function contractURI() external pure returns (string memory) {
        return "https://github.com/Crowdmuse/contracts";
    }

    /// @notice Retrieves the name of the minter contract
    /// @return A string representing the name of this minter contract
    function contractName() external pure returns (string memory) {
        return "Crowdmuse Escrow Minter";
    }

    /// @notice Retrieves the version of the minter contract
    /// @return A string representing the version of this minter contract
    function contractVersion() external pure returns (string memory) {
        return "0.0.1";
    }

    /// @notice Mints tokens to a specified address with an optional comment
    /// @param target The target CrowdmuseProduct contract address where the mint will occur
    /// @param mintTo The address that will receive the minted tokens
    /// @param garmentType The type of garment being minted, represented as a bytes32 hash
    /// @param quantity The quantity of tokens to mint
    /// @param comment An optional comment provided for the minting operation
    /// @return tokenId The token ID of the last minted token
    function mint(
        address target,
        address mintTo,
        bytes32 garmentType,
        uint256 quantity,
        string memory comment
    ) external nonReentrant returns (uint256 tokenId) {
        tokenId = _mint(target, mintTo, garmentType, quantity, comment);
    }

    /// @dev Internal function to handle the minting operation
    /// @param target The target CrowdmuseProduct contract address where the mint will occur
    /// @param mintTo The address that will receive the minted tokens
    /// @param garmentType The type of garment being minted, represented as a bytes32 hash
    /// @param quantity The quantity of tokens to mint
    /// @param comment An optional comment provided for the minting operation
    /// @return tokenId The token ID of the last minted token
    function _mint(
        address target,
        address mintTo,
        bytes32 garmentType,
        uint256 quantity,
        string memory comment
    ) internal returns (uint256 tokenId) {
        // Get the sales config
        SalesConfig storage config = salesConfigs[target];
        uint256 totalPrice = config.pricePerToken * quantity;

        _validateSaleConditions(target, mintTo, quantity);

        // Mint the token
        tokenId = ICrowdmuseProduct(target).buyPrepaidNFT(
            mintTo,
            garmentType,
            quantity
        );

        // Emit comment event
        if (bytes(comment).length > 0) {
            emit MintComment(mintTo, target, tokenId, quantity, comment);
        }

        _transferToEscrow(target, mintTo, totalPrice);

        // Redeem if sold out
        if (ICrowdmuseProduct(target).garmentsAvailable() == 0) {
            _redeem(target);
        }

        return tokenId;
    }

    /// @notice Configures the sale for a specific product by setting various parameters including the sale duration based on a predefined enum.
    /// @dev This function sets the sale configuration for the target contract and emits a SaleSet event upon successful execution.
    /// @param target The address of the target contract for which the sale configuration is being set.
    /// @param duration The minimum escrow duration selected from the MinimumEscrowDuration enum.
    function setSale(
        address target,
        MinimumEscrowDuration duration
    ) external onlyOwner(target) onlyIfInactive(target) {
        uint64 minimumNumberDays = getDaysForEnum(duration);
        uint64 saleEnd = uint64(block.timestamp + (minimumNumberDays * 1 days));

        ICrowdmuseProduct product = ICrowdmuseProduct(target);
        SalesConfig memory salesConfig = SalesConfig({
            saleStart: uint64(block.timestamp),
            saleEnd: saleEnd,
            maxTokensPerAddress: uint64(product.getMaxAmountOfTokensPerMint()),
            pricePerToken: uint96(product.buyNFTPrice()),
            fundsRecipient: target,
            erc20Address: address(product.paymentToken())
        });

        salesConfigs[target] = salesConfig;

        // Emit event
        emit SaleSet(target, salesConfig);
    }

    /// @notice Retrieves the sale configuration for a specified product.
    /// @dev Returns the sales configuration struct for the provided token contract address.
    /// @param tokenContract The address of the token contract for which the sale configuration is requested.
    /// @return The sales configuration struct for the given token contract.
    function sale(
        address tokenContract
    ) external view returns (SalesConfig memory) {
        return salesConfigs[tokenContract];
    }

    /// @notice Redeems escrowed funds for a given product, transferring them to the product's funds recipient.
    /// Can only be called by the owner of the target product contract.
    /// Deletes the sales configuration for the target product after redeeming the funds.
    /// @param target Address of the target product contract whose escrowed funds are to be redeemed.
    function redeem(address target) external onlyOwner(target) nonReentrant {
        _redeem(target);
    }

    /// @notice Redeems escrowed funds for a given product, transferring them to the product's funds recipient.
    /// Can only be called by the owner of the target product contract.
    /// Deletes the sales configuration for the target product after redeeming the funds.
    /// @param target Address of the target product contract whose escrowed funds are to be redeemed.
    function _redeem(address target) internal {
        SalesConfig storage config = salesConfigs[target];

        uint256 amount = balanceOf[target];

        IERC20(salesConfigs[target].erc20Address).transfer(
            config.fundsRecipient,
            amount
        );

        emit EscrowRedeemed(
            target,
            config.fundsRecipient,
            salesConfigs[target].erc20Address,
            amount
        );
        balanceOf[target] = 0;
        delete salesConfigs[target];
    }

    /// @notice Refunds escrowed funds to the owners of each token in a product.
    /// Iterates over each tokenId from 1 to product.totalSupply(), paying each product.ownerOf(tokenId).
    /// The amount paid is determined by config.pricePerToken.
    /// Can only be called by the owner of the target product contract.
    /// Can be called by any token owner of the target product contract after saleEnd.
    /// Resets the product's escrow balance after the refund process.
    /// @param target The address of the target product contract whose escrowed funds are to be refunded.
    /// @param refundRecipients List of refund recipients.
    function refund(
        address target,
        address[] memory refundRecipients
    ) external nonReentrant returns (address split) {
        SalesConfig storage config = salesConfigs[target];
        IERC721A productContract = IERC721A(target);
        uint256 totalSupply = productContract.totalSupply();

        if (!isOwner(target)) {
            // only owner can revert before saleEnd
            if (block.timestamp < config.saleEnd) {
                revert EscrowNotEnded();
                // tokenOwners can revert after saleEnd
            } else if (IERC721A(target).balanceOf(msg.sender) == 0) {
                revert EscrowNotTokenOwner();
            }
        }

        // verify escrow has price
        if (config.pricePerToken == 0) {
            revert EscrowPriceZero();
        }

        // refund all product owners
        split = _refund(target, refundRecipients);

        // After refunding all owners, ensure any remaining balance due to rounding or errors is cleared.
        if (balanceOf[target] > 0) {
            revert EscrowBalanceNotZero();
        }

        // Emit an event to log the refund action
        emit EscrowRefunded(
            target,
            config.erc20Address,
            totalSupply * config.pricePerToken
        );

        // Clear the sales configuration for the product after refunding
        delete salesConfigs[target];
    }

    /// @notice Refunds the escrowed funds to the original token owners for a specified product.
    /// @param target The address of the product contract.
    /// @param refundRecipients List of refund recipients.
    function _refund(
        address target,
        address[] memory refundRecipients
    )
        internal
        onlyValidRecipientList(target, refundRecipients)
        returns (address split)
    {
        SalesConfig storage config = salesConfigs[target];
        SplitReceiver[] memory splitRecipients = getRefundSplit(
            target,
            refundRecipients
        );
        split = createSplit(splitRecipients);
        IERC20(config.erc20Address).transfer(split, balanceOf[target]);
        balanceOf[target] = 0;
    }

    /// @dev Validates the sale conditions before minting. Reverts if conditions are not met.
    /// @param target The target CrowdmuseProduct contract address where the mint will occur
    /// @param mintTo The address that will receive the minted tokens
    /// @param quantity The quantity of tokens to mint
    function _validateSaleConditions(
        address target,
        address mintTo,
        uint256 quantity
    ) internal {
        SalesConfig storage config = salesConfigs[target];
        uint256 totalPrice = config.pricePerToken * quantity;

        // If sales config does not exist this first check will always fail.
        // Check sale end
        if (config.pricePerToken == 0) {
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
            _requireMintNotOverLimitAndUpdate(
                config.maxTokensPerAddress,
                quantity,
                target,
                mintTo
            );
        }
    }

    /// @dev Transfers the specified amount to escrow and updates the escrow balance for the target product
    /// @param target The product contract address
    /// @param mintTo The address that will receive the minted tokens
    /// @param amount The amount to transfer to escrow
    function _transferToEscrow(
        address target,
        address mintTo,
        uint256 amount
    ) internal {
        SalesConfig storage config = salesConfigs[target];

        // Transfer USDC to escrow
        IERC20(config.erc20Address).transferFrom(
            msg.sender,
            address(this),
            amount
        );

        // Track escrow funds for product
        unchecked {
            if (target != address(0)) {
                balanceOf[target] += amount;
                contributions[target][mintTo] += amount;
            }
        }

        // Emit escrow event
        emit EscrowDeposit(target, mintTo, amount);
    }

    /// @dev Checks if the redeem conditions are met.
    /// @param target The target CrowdmuseProduct contract address to check
    /// @return bool Returns true if conditions for auto redeem are met.
    function _shouldAutoRedeem(address target) internal view returns (bool) {
        uint256 totalSupply = IERC721A(target).totalSupply();
        uint256 garmentsAvailable = ICrowdmuseProduct(target)
            .garmentsAvailable();
        return totalSupply == garmentsAvailable;
    }

    /// @dev Checks if the caller is the owner of the target contract.
    /// @param target The target contract address whose ownership is to be verified.
    /// @return bool Returns true if the caller is the owner of the target contract.
    function isOwner(address target) internal view returns (bool) {
        return Ownable(target).owner() == msg.sender;
    }

    /// @dev Converts a MinimumEscrowDuration enum value to its corresponding number of days.
    /// @param duration The duration value of the enum MinimumEscrowDuration.
    /// @return durationDays The number of days corresponding to the enum value.
    function getDaysForEnum(
        MinimumEscrowDuration duration
    ) internal pure returns (uint64 durationDays) {
        if (duration == MinimumEscrowDuration.Days15) {
            durationDays = 15;
        } else if (duration == MinimumEscrowDuration.Days30) {
            durationDays = 30;
        } else if (duration == MinimumEscrowDuration.Days60) {
            durationDays = 60;
        } else if (duration == MinimumEscrowDuration.Days90) {
            durationDays = 90;
        }
    }

    function getRefundSplit(
        address target,
        address[] memory refundRecipients
    ) internal view returns (SplitReceiver[] memory splitReceivers) {
        uint256 totalRecipients = refundRecipients.length;
        splitReceivers = new SplitReceiver[](totalRecipients);

        for (uint256 i = 0; i < totalRecipients; i++) {
            address recipient = refundRecipients[i];
            uint256 contribution = contributions[target][recipient];

            splitReceivers[i] = SplitReceiver({
                receiver: recipient,
                allocation: uint32(contribution)
            });
        }
    }

    /// @dev Modifier to restrict functions to the owner of the target contract.
    /// Throws `OwnableUnauthorizedAccount` if the caller is not the owner.
    /// @param target Address of the target contract to check ownership against.
    modifier onlyOwner(address target) {
        if (!isOwner(target)) {
            revert Ownable.OwnableUnauthorizedAccount(msg.sender);
        }

        _;
    }

    /// @dev Ensures a sale configuration is not already active for the given target.
    /// @param target The target contract address for which the sale config is being verified.
    modifier onlyIfInactive(address target) {
        if (salesConfigs[target].pricePerToken != 0) {
            revert EscrowAlreadyExists();
        }

        _;
    }

    /// @dev Ensures a refund list is valid for the given target.
    /// @param target The target contract address for which the refund list is being verified.
    /// @param refundRecipients List of refund recipients.
    modifier onlyValidRecipientList(
        address target,
        address[] memory refundRecipients
    ) {
        for (uint256 i = 0; i < refundRecipients.length; i++) {
            if (contributions[target][refundRecipients[i]] == 0) {
                revert EscrowNotValidRefundList();
            }
        }
        _;
    }
}
