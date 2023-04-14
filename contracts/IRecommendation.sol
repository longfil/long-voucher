// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IRecommendation {
    struct Recommendation {
        uint256 atBlock;
        address referrer;
    }

    function isReferrer(address referrer) external view returns (bool);

    function getRecommendation(address referral) external view returns (bool, Recommendation memory);
}
