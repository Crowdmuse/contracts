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

    // MOVE TO CROWDMUSE SPLITS LIB
    function createSplit() internal returns (address split) {
        SplitV2Lib.Split memory splitParams = getSplitParams();
        address owner = address(0);
        split = pushSplitFactory.createSplit(splitParams, owner, owner);
    }

    function distributeSplit(address split, address token) internal {
        SplitV2Lib.Split memory splitParams = getSplitParams();
        address distributor = address(this);
        PushSplit(split).distribute(splitParams, token, distributor);
    }

    function getSplitParams()
        internal
        pure
        returns (SplitV2Lib.Split memory splitParams)
    {
        uint256 lengthToTest = 100_000;
        uint256 sharePerToken = 100;
        address[] memory _receivers = new address[](lengthToTest);
        uint[] memory _amounts = new uint[](lengthToTest);
        for (uint i; i < lengthToTest; i++) {
            _receivers[i] = address(uint160(i + 1));
            _amounts[i] = sharePerToken;
        }
        splitParams = SplitV2Lib.Split({
            recipients: _receivers,
            allocations: _amounts,
            totalAllocation: sharePerToken * lengthToTest,
            distributionIncentive: 0
        });
    }
}
