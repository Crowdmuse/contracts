// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface ICrowdmuseProduct {
    enum TaskStatus {
        Open,
        Assigned,
        Complete
    }

    struct Task {
        uint256[] contributionValues;
        address[] taskContributors;
        TaskStatus[] taskStatus;
        uint256[] taskContributorTypes;
    }
}
