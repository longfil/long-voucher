// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./ILongVoucher.sol";

interface IProductCenter {
    struct ProductParameters {
        uint256 totalQuota;
        uint256 minSubscriptionAmount;
        uint256 beginSubscriptionBlock;
        uint256 endSubscriptionBlock;
        uint256 minHoldingDuration;
        address interestRate;
        address cashPool;
    }

    struct Subscription {
        address subscriber;
        uint256 atBlock;
        uint256 principal;
        uint256 voucherId;
    }

    function longVoucher() external view returns (ILongVoucher);

    function productCount() external view returns (uint256);

    function productByIndex(uint256 index_) external view returns (uint256);

    function getProductParameters(uint256 productId) external view returns (ProductParameters memory);

    function getTotalFunds(uint256 productId) external view returns (uint256);

    function getTotalLoans(uint256 productId) external view returns (uint256);

    function isSubscriber(uint256 productId, address subscriber) external view returns (bool);

    function getSubscription(uint256 productId, address subscriber) external view returns (Subscription memory);

    function isRedeemable(uint256 voucherId) external view returns (bool);

    function voucherInterest(uint256 voucherId) external view returns (uint256);

    function voucherPrincipalAndInterest(uint256 voucherId) external view returns (uint256);

    function productInterest(uint256 productId) external view returns (uint256);

    function productPrincipalAndInterest(uint256 productId) external view returns (uint256);
}