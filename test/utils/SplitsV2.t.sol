// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {SplitsWarehouse} from "splits-v2/SplitsWarehouse.sol";
import {PushSplitFactory} from "splits-v2/splitters/push/PushSplitFactory.sol";
import {SplitV2Lib} from "splits-v2/libraries/SplitV2.sol";

contract SplitsV2Test is Test {
    SplitsWarehouse internal splitsWarehouse =
        new SplitsWarehouse("SPLITS V2", "SPLITS");
    PushSplitFactory internal pushSplitFactory =
        new PushSplitFactory(address(splitsWarehouse));

    function test_SplitsWarehouseSetup() external view {
        assertEq(splitsWarehouse.PERCENTAGE_SCALE(), 1000000);
    }

    function test_createSplit() external {
        uint256 lengthToTest = 100_000;
        address[] memory _receivers = new address[](lengthToTest);
        uint[] memory _amounts = new uint[](lengthToTest);
        for (uint i; i < lengthToTest; i++) {
            _receivers[i] = address(uint160(i + 1));
            _amounts[i] = 100;
        }

        SplitV2Lib.Split memory splitParams = SplitV2Lib.Split({
            recipients: _receivers,
            allocations: _amounts,
            totalAllocation: 100 * lengthToTest,
            distributionIncentive: 0
        });

        address owner = address(0);
        address split = pushSplitFactory.createSplit(splitParams, owner, owner);
        assertTrue(isContract(split));
    }

    function isContract(address _addr) internal view returns (bool response) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        response = size > 0;
    }
}
