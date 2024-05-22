// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {PushSplitFactory} from "splits-v2/splitters/push/PushSplitFactory.sol";
import {PushSplit} from "splits-v2/splitters/push/PushSplit.sol";
import {SplitV2Lib} from "splits-v2/libraries/SplitV2.sol";

/// @title SplitsV2
/// @notice A lib for interacting with SplitsV2 protocol
contract SplitsV2 {
    /// @notice The PushSplitFactory contract
    PushSplitFactory public pushSplitFactory;

    constructor(address _pushSplitFactory) {
        pushSplitFactory = PushSplitFactory(_pushSplitFactory);
    }

    function createSplit(
        SplitReceiver[] memory refundList
    ) internal returns (address split) {
        SplitV2Lib.Split memory splitParams = getSplitParams(refundList);
        address owner = address(0);
        split = pushSplitFactory.createSplit(splitParams, owner, owner);
    }

    function getSplitParams(
        SplitReceiver[] memory refundList
    ) internal pure returns (SplitV2Lib.Split memory splitParams) {
        uint256 totalRecipients = refundList.length;
        address[] memory receivers = new address[](totalRecipients);
        uint256[] memory allocations = new uint256[](totalRecipients);
        uint256 totalAllocation = 0;

        for (uint256 i = 0; i < totalRecipients; i++) {
            receivers[i] = refundList[i].receiver;
            allocations[i] = uint256(refundList[i].allocation);
            totalAllocation += allocations[i];
        }

        splitParams = SplitV2Lib.Split({
            recipients: receivers,
            allocations: allocations,
            totalAllocation: totalAllocation,
            distributionIncentive: 0
        });
    }

    struct SplitReceiver {
        address receiver;
        uint32 allocation;
    }
}
