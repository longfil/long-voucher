// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IRecommendationCenter {
    function referredProductCount(address referrer) external view returns (uint256);

    function referredProductIdByIndex(address referrer, uint256 index) external view returns (uint256);

    function getTotalEquities(address referrer, uint256 productId) external view returns (uint256);

    function accruedEarnings(address referrer, uint256 productId) external view returns (uint256);
}


contract RecommendationCenterHelper {

    struct ReferredProduct {
        uint256 productId;
        uint256 totalEquities;
        uint256 accruedEarnings;
    }

    function getReferredProductList(IRecommendationCenter recommendationCenter, address referrer) external view returns (ReferredProduct[] memory) {
        uint256 referredCount = recommendationCenter.referredProductCount(referrer);

        ReferredProduct[] memory result = new ReferredProduct[](referredCount);
        for (uint i = 0; i < referredCount; i++) {
            uint256 productId = recommendationCenter.referredProductIdByIndex(referrer, i);

            ReferredProduct memory referredProduct = result[i];
            referredProduct.productId = productId;
            referredProduct.totalEquities = recommendationCenter.getTotalEquities(referrer, productId);
            referredProduct.accruedEarnings = recommendationCenter.accruedEarnings(referrer, productId);
        }

        return result;
    }
}