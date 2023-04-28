// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../IProductCenter.sol";
import "../ILongVoucherMetadataProvider.sol";

contract ProductCenterHelper {

    ILongVoucher public longVoucher;

    constructor(address longVoucher_) {
        require(longVoucher_ != address(0), "zero address");

        longVoucher = ILongVoucher(longVoucher_);
    }

    function getProductInfo(uint256 productId) external view 
        returns (IProductCenter.ProductParameters memory parameters, string memory metadata) {
        IProductCenter productCenter = IProductCenter(longVoucher.managerOf(productId));

        parameters = productCenter.getProductParameters(productId);
        metadata = longVoucher.slotURI(productId);
    } 

    function getProductIdsAll(address productCenter_) external view returns (uint256[] memory) {
        IProductCenter productCenter = IProductCenter(productCenter_);
        uint256 productCount = productCenter.productCount(); 

        uint256 counter = productCount;
        uint256[] memory productIds = new uint256[](productCount);
        for (uint256 i = 0; i < productCount; i ++) {
            uint256 productId = productCenter.productIdByIndex(i);
            productIds[--counter] = productId;
        }

        return productIds;
    }

    function getProductIdsInPreSubscriptionStage(address productCenter_) external view returns (uint256[] memory) {
        IProductCenter productCenter = IProductCenter(productCenter_);
        uint256 productCount = productCenter.productCount(); 

        uint256 counter = 0;
        for (uint256 i = 0; i < productCount; i ++) {
            uint256 productId = productCenter.productIdByIndex(i);
            IProductCenter.ProductParameters memory parameters = productCenter.getProductParameters(productId);
            if (block.number < parameters.beginSubscriptionBlock) {
                counter++;
            }
        }

        uint256[] memory productIds = new uint256[](counter);
        for (uint256 i = 0; i < productCount; i ++) {
            uint256 productId = productCenter.productIdByIndex(i);
            IProductCenter.ProductParameters memory parameters = productCenter.getProductParameters(productId);
            if (block.number < parameters.beginSubscriptionBlock) {
                productIds[--counter] = productId;
            }
        }

        return productIds;
    }

    function getProductIdsInSubscriptionStage(address productCenter_) external view returns (uint256[] memory) {
        IProductCenter productCenter = IProductCenter(productCenter_);
        uint256 productCount = productCenter.productCount(); 

        uint256 counter = 0;
        for (uint256 i = 0; i < productCount; i ++) {
            uint256 productId = productCenter.productIdByIndex(i);
            IProductCenter.ProductParameters memory parameters = productCenter.getProductParameters(productId);
            if (block.number >= parameters.beginSubscriptionBlock && block.number < parameters.endSubscriptionBlock) {
                counter++;
            }
        }

        uint256[] memory productIds = new uint256[](counter);
        for (uint256 i = 0; i < productCount; i ++) {
            uint256 productId = productCenter.productIdByIndex(i);
            IProductCenter.ProductParameters memory parameters = productCenter.getProductParameters(productId);
            if (block.number >= parameters.beginSubscriptionBlock && block.number < parameters.endSubscriptionBlock) {
                productIds[--counter] = productId;
            }
        }

        return productIds;
    }

    function getProductIdsInOnlineStage(address productCenter_) external view returns (uint256[] memory) {
        IProductCenter productCenter = IProductCenter(productCenter_);
        uint256 productCount = productCenter.productCount(); 

        uint256 counter = 0;
        for (uint256 i = 0; i < productCount; i ++) {
            uint256 productId = productCenter.productIdByIndex(i);
            IProductCenter.ProductParameters memory parameters = productCenter.getProductParameters(productId);
            if (block.number >= parameters.endSubscriptionBlock) {
                counter++;
            }
        }

        uint256[] memory productIds = new uint256[](counter);
        for (uint256 i = 0; i < productCount; i ++) {
            uint256 productId = productCenter.productIdByIndex(i);
            IProductCenter.ProductParameters memory parameters = productCenter.getProductParameters(productId);
            if (block.number >= parameters.endSubscriptionBlock) {
                productIds[--counter] = productId;
            }
        }

        return productIds;
    }

    function getProductIdsBySubscriber(address productCenter_, address subscriber) external view returns (uint256[] memory) {
        IProductCenter productCenter = IProductCenter(productCenter_);
        uint256 productCount = productCenter.productCount(); 

        uint256 counter = 0;
        for (uint256 i = 0; i < productCount; i ++) {
            uint256 productId = productCenter.productIdByIndex(i);
            if (productCenter.isSubscriber(productId, subscriber)) {
                counter++;
            }
        }

        uint256[] memory productIds = new uint256[](counter);
        for (uint256 i = 0; i < productCount; i ++) {
            uint256 productId = productCenter.productIdByIndex(i);
            if (productCenter.isSubscriber(productId, subscriber)) {
                productIds[--counter] = productId;
            }
        }

        return productIds;
    }

    function getSubscription(
        address productCenter_,
        uint256 productId,
        address subscriber
    ) external view returns (IProductCenter.Subscription memory subscription) {
        IProductCenter productCenter = IProductCenter(productCenter_);
        return productCenter.getSubscription(productId, subscriber); 
    }
}

