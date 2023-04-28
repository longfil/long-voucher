// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IRecommendationCenterConsumer {
    function equitiesInterest(uint256 productId, uint256 equities, uint256 endBlock) external view returns (uint256);
}

