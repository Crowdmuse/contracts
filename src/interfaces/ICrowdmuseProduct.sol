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

    struct Token {
        string productName;
        string productSymbol;
        string baseUri;
        uint256 maxAmountOfTokensPerMint;
    }

    struct Inventory {
        string keyName;
        uint96 garmentsRemaining;
    }

    enum ProductStatus {
        InProgress,
        Complete
    }

    enum NFTTypes {
        Default,
        Product,
        Contributor,
        Investor
    }

    struct TaskInformation {
        uint256 taskId;
        uint256 contributionValue;
        address taskOwnerAddress;
        address taskContributor;
        uint256[] licensedProjects;
        uint24 feedbackScore;
        string submissionUri;
        string taskMetadataUri;
        TaskStatus taskStatus;
        uint256 taskType;
    }
}
