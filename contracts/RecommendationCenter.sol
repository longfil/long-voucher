// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./ICashPoolConsumer.sol";
import "./ILongVoucher.sol";
import "./IRecommendation.sol";
import "./IRecommendationCenter.sol";
import "./IRecommendationCenterConsumer.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

contract RecommendationCenter is
    Ownable2StepUpgradeable,
    IRecommendationCenter,
    ICashPoolConsumer,
    IERC165Upgradeable
{
    uint256 private constant MANTISSA_ONE = 1e18;

    struct ReferredProduct {
        uint256 productId;
        uint256 totalEquities;
        uint256 settledInterest;
        uint256[5] __gap;
    }

    struct ReferrerData {
        uint256 distributedEarnings;
        ReferredProduct[] allReferredProducts;
        mapping(uint256 => uint256) allReferredProductsIndex;
        uint256[5] __gap;
    }

    struct ConsumerData {
        address consumer;
        uint256 referrerEarningsRatio;
        uint256[5] __gap;
    }

    /// storage

    ILongVoucher public longVoucher;
    IRecommendation public recommendation;
    uint256 public referrerEarningsSlot;

    // referrer => referrer data
    mapping(address => ReferrerData) private _referrerDataMapping;

    // voucher id => tracking flag
    mapping(uint256 => bool) private _voucherTrackingFlag;

    // ConsumerData set
    ConsumerData[] private _allConsumerData;

    // consumer => consumer data index
    mapping(address => uint256) private _allConsumerDataIndex;

    /// events

    event AddedConsumer(address consumer, uint256 referrerEarningsRatio);
    event Settlement(
        address indexed referrer, 
        uint256 indexed productId, 
        uint256 oldTotalEquities, 
        uint256 newTotalEquities,
        uint256 oldSettledInterest,
        uint256 newSettledInterest
    );
    event DistributedEarningsChanged(
        address indexed referrer, 
        uint256 oldDistributedEarnings, 
        uint256 newDistributedEarnings 
    );
    event Claimed(address indexed referrer, uint256 earnings, uint256 voucherId);

    /**
     * initialize method, called by proxy
     */
    function initialize(
        address longVoucher_,
        address recommendation_,
        uint256 referrerEarningsSlot_,
        address initialOwner_
    ) public initializer {
        require(longVoucher_ != address(0), "zero address");
        require(recommendation_ != address(0), "zero address");
        require(initialOwner_ != address(0), "zero address");

        // call super initialize methods
        Ownable2StepUpgradeable.__Ownable2Step_init();

        // set storage values
        longVoucher = ILongVoucher(longVoucher_);
        recommendation = IRecommendation(recommendation_);
        referrerEarningsSlot = referrerEarningsSlot_;

        // test
        recommendation.isReferrer(initialOwner_);

        // initialize owner
        _transferOwnership(initialOwner_);
    }

    // ERC165
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return interfaceId == type(IRecommendationCenter).interfaceId || interfaceId == type(ICashPoolConsumer).interfaceId;
    }

    /// admin function

    function addConsumer(address consumer_, uint256 referrerEarningsRatio_) external onlyOwner {
        require(consumer_ != address(0), "zero address");
        require(referrerEarningsRatio_ <= MANTISSA_ONE, "illegal referrer earnings ratio");
        require(!_existsConsumer(consumer_), "consumer exists");

        uint256 index = _allConsumerData.length;

        _allConsumerData.push();
        ConsumerData storage consumerData = _allConsumerData[index];
        consumerData.consumer = consumer_;
        consumerData.referrerEarningsRatio = referrerEarningsRatio_;

        emit AddedConsumer(consumer_, referrerEarningsRatio_);
    }

    ///

    function isVoucherTracked(uint256 voucherId) external view returns (bool) {
        return _voucherTrackingFlag[voucherId];
    }

    function consumerCount() public view returns (uint256) {
        return _allConsumerData.length;
    }

    function consumerByIndex(uint256 index) external view returns (address) {
        require(index < consumerCount(), "index exceeds");
        return _allConsumerData[index].consumer;
    }

    function getReferrerEarningsRatio(address consumer) external view returns (uint256) {
        require(_existsConsumer(consumer));
        return _getConsumerData(consumer).referrerEarningsRatio;
    }

    function referredProductCount(address referrer) public view returns (uint256) {
        return _referrerDataMapping[referrer].allReferredProducts.length;
    }

    function referredProductIdByIndex(address referrer, uint256 index) external view returns (uint256) {
        require(index < referredProductCount(referrer), "index exceeds");
        return _referrerDataMapping[referrer].allReferredProducts[index].productId;
    }

    function getDistributedEarnings(address referrer) external view returns (uint256) {
        return _referrerDataMapping[referrer].distributedEarnings;
    }

    function getTotalEquities(address referrer, uint256 productId) external view returns (uint256) {
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        if (!_existsReferredProduct(referrerData, productId)) {
            return 0;
        }
        return _getReferredProduct(referrerData, productId).totalEquities;
    }

    function getSettledInterest(address referrer, uint256 productId) external view returns (uint256) {
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        if (!_existsReferredProduct(referrerData, productId)) {
            return 0;
        }
        return _getReferredProduct(referrerData, productId).settledInterest;
    }

    function accruedEarnings(address referrer) external view returns (uint256) {
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        uint256 allReferredProductsCount = referrerData.allReferredProducts.length;

        uint256 undistributedEarnings = 0;
        for (uint256 i = 0; i < allReferredProductsCount; i++) {
            ReferredProduct memory referredProduct = referrerData.allReferredProducts[i];
            ConsumerData memory consumerData = _getConsumerData(longVoucher.managerOf(referredProduct.productId));

            (uint256 unsettledInterest, ) = _productUnsettledInterest(consumerData.consumer, referredProduct);
            undistributedEarnings += _calculateEarnings(unsettledInterest, consumerData.referrerEarningsRatio);
        }

        return referrerData.distributedEarnings + undistributedEarnings;
    }

    function accruedEarnings(address referrer, uint256 productId) external view returns (uint256) {
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        if (!_existsReferredProduct(referrerData, productId)) {
            return 0;
        }

        ReferredProduct memory referredProduct = _getReferredProduct(referrerData, productId);
        ConsumerData memory consumerData = _getConsumerData(longVoucher.managerOf(productId));

        (uint256 unsettledInterest, ) = _productUnsettledInterest(consumerData.consumer, referredProduct);
        return _calculateEarnings(unsettledInterest, consumerData.referrerEarningsRatio);
    }

    /// state functions 

    function trackVoucher(uint256 voucherId) external {
        if (!_voucherTrackingFlag[voucherId]) {
            address referral = longVoucher.ownerOf(voucherId);
            (bool exists, IRecommendation.ReferralInfo memory referralInfo) = recommendation.getReferralInfo(referral);
            require(exists, "referral not exists");

            uint256 productId = longVoucher.slotOf(voucherId);
            address consumer = longVoucher.managerOf(productId);
            require(_existsConsumer(consumer), "illegal consumer");

            ReferrerData storage referrerData = _referrerDataMapping[referralInfo.referrer];
            ReferredProduct storage referredProduct = _tryTrackProduct(referrerData, productId);
            ReferredProduct memory referredProductBackup = referredProduct;

            _trackVoucher(IRecommendationCenterConsumer(consumer), referralInfo, referredProduct, voucherId, longVoucher.balanceOf(voucherId));

            emit Settlement(
                referralInfo.referrer, 
                productId, 
                referredProductBackup.totalEquities, 
                referredProduct.totalEquities, 
                referredProductBackup.settledInterest, 
                referredProduct.settledInterest
            );
        }
    }

    // claim distributed earnings
    function claimEarnings(address receiver) external returns (uint256 voucherId) {
        require(receiver != address(0), "zero address");

        address referrer = _msgSender();
        voucherId = _claimDistributedEarnings(referrer, receiver);
    }

    function claimEarnings(address receiver, uint256[] calldata productIdSet) external returns (uint256 voucherId) {
        require(receiver != address(0), "zero address");

        address referrer = _msgSender();
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        for (uint256 i = 0; i < productIdSet.length; i++) {
            uint256 productId = productIdSet[i];
            if (_existsReferredProduct(referrerData, productId)) {
                _settleProduct(referrer, referrerData, productId);
            }
        }

        voucherId =_claimDistributedEarnings(referrer, receiver);
    }

    function _claimDistributedEarnings(address referrer, address receiver) private returns (uint256 voucherId) {
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        if (referrerData.distributedEarnings > 0) {
            // save referrerData.distributedEarnings
            uint256 oldDistributedEarnings = referrerData.distributedEarnings;

            // set settledEarnings to 0
            referrerData.distributedEarnings = 0;
            voucherId = longVoucher.mint(receiver, referrerEarningsSlot, oldDistributedEarnings);

            emit DistributedEarningsChanged(referrer, oldDistributedEarnings, 0);
            emit Claimed(referrer, oldDistributedEarnings, voucherId);
        }
    }

    function _settleProduct(address referrer, ReferrerData storage referrerData, uint256 productId) private {
        ReferredProduct storage referredProduct = _getReferredProduct(referrerData, productId);
        ConsumerData memory consumerData = _getConsumerData(longVoucher.managerOf(productId));

        (uint256 unsettledInterest, uint256 currentInterest) = _productUnsettledInterest(consumerData.consumer, referredProduct); 

        uint256 oldSettledInterest = referredProduct.settledInterest;
        referrerData.distributedEarnings += _calculateEarnings(unsettledInterest, consumerData.referrerEarningsRatio);
        referredProduct.settledInterest = currentInterest;

        emit Settlement(referrer, productId, referredProduct.totalEquities, referredProduct.totalEquities, oldSettledInterest, currentInterest);
    }

    function _productUnsettledInterest(address consumer, ReferredProduct memory referredProduct) private view returns (uint256, uint256) {
        uint256 currentInterest = 
            IRecommendationCenterConsumer(consumer).equitiesInterest(referredProduct.productId, referredProduct.totalEquities, block.number);
        return (currentInterest - referredProduct.settledInterest, currentInterest);
    }

    function _existsReferredProduct(ReferrerData storage referrerData, uint256 productId) private view returns (bool) {
        return referrerData.allReferredProducts.length > 0 && _getReferredProduct(referrerData, productId).productId == productId;
    }

    function _getReferredProduct(ReferrerData storage referrerData, uint256 productId) private view returns (ReferredProduct storage) {
        return referrerData.allReferredProducts[referrerData.allReferredProductsIndex[productId]];
    }

    function _calculateEarnings(uint256 interest, uint256 referrerEarningsRatio) private pure returns (uint256) {
        return interest * referrerEarningsRatio / MANTISSA_ONE;
    }

    function _existsConsumer(address consumer) private view returns (bool) {
        return _allConsumerData.length > 0 && _allConsumerData[_allConsumerDataIndex[consumer]].consumer == consumer;
    }

    function _getConsumerData(address consumer) private view returns (ConsumerData memory) {
        return  _allConsumerData[_allConsumerDataIndex[consumer]];
    }

    /// implement ICashPoolConsumer

    function isRedeemable(uint256 voucherId) external view returns (bool) {
        require(longVoucher.slotOf(voucherId) == referrerEarningsSlot, "illegal voucher");
        return true;
    }

    function getRedeemableAmount(uint256 voucherId) external view returns (uint256) {
        require(longVoucher.slotOf(voucherId) == referrerEarningsSlot, "illegal voucher");
        return longVoucher.balanceOf(voucherId);
    }

    /// implement IRecommendationCenter

    struct ReferralWrap {
        bool exists;
        IRecommendation.ReferralInfo info;
    }

    function onEquitiesTransfer(
        uint256 productId_,
        address from_,
        address to_,
        uint256 fromVoucherId_,
        uint256 toVoucherId_,
        uint256 value_
    ) external override {
        require(_msgSender() == longVoucher.managerOf(productId_), "illegal product");
        require(_existsConsumer(_msgSender()), "illegal caller");

        ConsumerData memory consumerData = _getConsumerData(_msgSender());

        _onEquitiesTransferOut(consumerData, productId_, from_, fromVoucherId_, value_);
        _onEquitiesTransferIn(consumerData, productId_, to_, toVoucherId_, value_);
    }

    function _onEquitiesTransferOut(
        ConsumerData memory consumerData,
        uint256 productId_,
        address from_,
        uint256 fromVoucherId_,
        uint256 value_
    ) private {
        (bool exists, IRecommendation.ReferralInfo memory referralInfo) = recommendation.getReferralInfo(from_);

        if (exists) {
            ReferrerData storage referrerData = _referrerDataMapping[referralInfo.referrer];
            ReferredProduct storage referredProduct = _tryTrackProduct(referrerData, productId_);
            ReferredProduct memory referredProductBackup = referredProduct;

            if (!_voucherTrackingFlag[fromVoucherId_]) {
                _trackVoucher(IRecommendationCenterConsumer(consumerData.consumer), referralInfo, referredProduct, 
                    fromVoucherId_, longVoucher.balanceOf(fromVoucherId_) + value_);
            }

            uint256 interestToSettle = IRecommendationCenterConsumer(consumerData.consumer).equitiesInterest(productId_, value_, block.number);
            if (interestToSettle <= referredProduct.settledInterest) {
                referredProduct.settledInterest -= interestToSettle;
            } else {
                uint256 oldDistributedEarnings = referrerData.distributedEarnings; 

                referrerData.distributedEarnings += 
                    _calculateEarnings(interestToSettle - referredProduct.settledInterest, consumerData.referrerEarningsRatio);
                referredProduct.settledInterest = 0;

                emit DistributedEarningsChanged(referralInfo.referrer, oldDistributedEarnings, referrerData.distributedEarnings);
            }
            referredProduct.totalEquities -= value_;

            emit Settlement(
                referralInfo.referrer,
                productId_,
                referredProductBackup.totalEquities,
                referredProduct.totalEquities,
                referredProductBackup.settledInterest,
                referredProduct.settledInterest
            );

            if (referredProduct.totalEquities == 0) {
                _removeReferredProduct(referrerData, productId_);
            }
        }
    }

    function _onEquitiesTransferIn(
        ConsumerData memory consumerData,
        uint256 productId_,
        address to_,
        uint256 toVoucherId_,
        uint256 value_
    ) private {
        (bool exists, IRecommendation.ReferralInfo memory referralInfo) = recommendation.getReferralInfo(to_);

        if (exists) {
            ReferrerData storage referrerData = _referrerDataMapping[referralInfo.referrer];
            ReferredProduct storage referredProduct = _tryTrackProduct(referrerData, productId_);
            ReferredProduct memory referredProductBackup = referredProduct;

            if (!_voucherTrackingFlag[toVoucherId_]) {
                _trackVoucher(IRecommendationCenterConsumer(consumerData.consumer), referralInfo, referredProduct, 
                    toVoucherId_, longVoucher.balanceOf(toVoucherId_) - value_);
            }

            referredProduct.totalEquities += value_;
            referredProduct.settledInterest += 
                IRecommendationCenterConsumer(consumerData.consumer).equitiesInterest(productId_, value_, block.number);

            emit Settlement(
                referralInfo.referrer,
                productId_,
                referredProductBackup.totalEquities,
                referredProduct.totalEquities,
                referredProductBackup.settledInterest,
                referredProduct.settledInterest
            );
        }
    }

    function _tryTrackProduct(
        ReferrerData storage referrerData,
        uint256 productId
    ) private returns (ReferredProduct storage referredProduct) {
        if (!_existsReferredProduct(referrerData, productId)) {
            uint256 index = referrerData.allReferredProducts.length;

            // resize 
            referrerData.allReferredProducts.push();
            referrerData.allReferredProductsIndex[productId] = index;

            referredProduct = referrerData.allReferredProducts[index];
            referredProduct.productId = productId;
        } else {
            referredProduct = _getReferredProduct(referrerData, productId);
        }
    }

    function _trackVoucher(
        IRecommendationCenterConsumer consumer,
        IRecommendation.ReferralInfo memory referralInfo,
        ReferredProduct storage referredProduct,
        uint256 voucherId, 
        uint256 equities
    ) private {
        if (equities > 0) {
            uint256 settledInterest = consumer.equitiesInterest(referredProduct.productId, equities, referralInfo.bindAt);

            referredProduct.totalEquities += equities;
            referredProduct.settledInterest += settledInterest;
        }

        _voucherTrackingFlag[voucherId] = true;
    }

    function _removeReferredProduct(ReferrerData storage referrerData, uint256 productId) private {
        uint256 lastReferredProductIndex = referrerData.allReferredProducts.length - 1;
        ReferredProduct memory lastReferredProduct = referrerData.allReferredProducts[lastReferredProductIndex];
        uint256 targetIndex = referrerData.allReferredProductsIndex[productId];

        referrerData.allReferredProducts[targetIndex] = lastReferredProduct;
        referrerData.allReferredProductsIndex[lastReferredProduct.productId] = targetIndex;

        delete referrerData.allReferredProductsIndex[productId];
        referrerData.allReferredProducts.pop();
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[43] private __gap;
}