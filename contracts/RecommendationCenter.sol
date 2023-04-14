// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./ILongVoucher.sol";
import "./IProductCenter.sol";
import "./IRecommendation.sol";
import "./IRecommendationCenter.sol";
import "./ISlotManager.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

contract RecommendationCenter is
    Ownable2StepUpgradeable,
    EIP712Upgradeable,
    IERC165Upgradeable,
    ISlotManager,
    IRecommendation,
    IRecommendationCenter
{
    uint256 private constant MANTISSA_ONE = 1e18;

    uint256 public constant QUALIFICATION_SLOT_ID = 20;
    uint256 public constant EARNINGS_SLOT_ID = 21;
    bytes32 public constant RECOMMENDATION_TYPEHASH = keccak256("Referrer(address referrer)");

    struct RecommendationData {
        uint256 atBlock;
        address referrer;
    }

    struct ProductStatus {
        address productCenter; 
        uint256 productId;
        uint256 equities;
        uint256 settledInterest;
        mapping(uint256 => bool) voucherTrackedFlag;
    }

    struct ReferrerData {
        uint256 settledEarnings;
        ProductStatus[] allProductStatus;
        mapping(uint256 => uint256) allProductStatusIndex;
    }

    /// storage

    ILongVoucher public longVoucher;
    uint256 public referrerEarningsRatioMantissa;

    // referrer => qualification token counter
    mapping(address => uint256) private _referrerQualification;

    // referral => recommendation
    mapping(address => RecommendationData) private _referralRecommendations;

    // referrer => referrer data
    mapping(address => ReferrerData) private _referrerDataMapping;

    /// events

    event Mint(address receiver, uint256 qualificationId);
    event Bind(address indexed referrer, address referral, uint256 atBlock);
    event Claimed(address indexed referrer, address receiver, uint256 earnings, uint256 voucherId);

    /**
     * initialize method, called by proxy
     */
    function initialize(
        address longVoucher_,
        uint256 referrerEarningsRatioMantissa_,
        address initialOwner_
    ) public initializer {
        require(referrerEarningsRatioMantissa_ <= MANTISSA_ONE, "illegal earnings ratio");
        require(initialOwner_ != address(0), "zero address");

        // call super initialize methods
        Ownable2StepUpgradeable.__Ownable2Step_init();
        EIP712Upgradeable.__EIP712_init(name(), version());

        // set storage values
        longVoucher = ILongVoucher(longVoucher_);
        referrerEarningsRatioMantissa = referrerEarningsRatioMantissa_;

        // initialize owner
        _transferOwnership(initialOwner_);

        // take up QUALIFICATION_SLOT_ID by mint new token
        longVoucher.mint(address(this), QUALIFICATION_SLOT_ID, 0);

        // take up EARNINGS_SLOT_ID by mint new token
        longVoucher.mint(address(this), EARNINGS_SLOT_ID, 0);
    }

    // ERC165
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return interfaceId == type(ISlotManager).interfaceId || interfaceId == type(IRecommendationCenter).interfaceId;
    }

    /**
     * mint qualification 
     */
    function mint(address receiver) external onlyOwner returns (uint256 qualificationId) {
        require(receiver != address(0), "zero address");

        qualificationId = longVoucher.mint(receiver, QUALIFICATION_SLOT_ID, 0);
        emit Mint(receiver, qualificationId);
    }

    /**
     */
    function name() public pure returns (string memory) {
        return "LongFil Recommendation";
    }

    /**
     */
    function version() public pure returns (string memory) {
        return "1";
    }

    /**
     */
    function bind(address referrer, uint8 v, bytes32 r, bytes32 s) external {
        require(isReferrer(referrer), "missing qualification");

        address referral = ECDSAUpgradeable.recover(
            _hashTypedDataV4(
                keccak256(abi.encode(RECOMMENDATION_TYPEHASH, referrer))
            ),
            v,
            r,
            s
        );
        require(referrer != referral, "illegal referral");
        require(!_existsRecommendation(referral), "already bind");

        // update storage 
        _referralRecommendations[referral] = RecommendationData({atBlock: block.number, referrer: referrer}) ;

        emit Bind(referral, referrer, block.number);
    }

    /// implement IRecommendation

    function isReferrer(address referrer) public view override returns (bool) {
        return _referrerQualification[referrer] > 0;
    }

    function getRecommendation(address referral) external view override returns (bool hasRecommendation, Recommendation memory recommendation) {
        if (_existsRecommendation(referral)) {
            RecommendationData memory recommendationData = _referralRecommendations[referral];
            recommendation = Recommendation({
                atBlock: recommendationData.atBlock,
                referrer: recommendationData.referrer
            });

            hasRecommendation = true;
        }
    }

    function trackedProductCount(address referrer) external view returns (uint256) {
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        return referrerData.allProductStatus.length;
    }

    function trackedProductIdByIndex(address referrer, uint256 index) external view returns (uint256) {
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        return referrerData.allProductStatus[index].productId;
    }

    function accruedEarnings(address referrer) external view returns (uint256) {
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        uint256 totalAvailableInterest = 0;
        for (uint256 i = 0; i < referrerData.allProductStatus.length; i++) {
            ProductStatus storage productStatus = referrerData.allProductStatus[i];

            uint256 productAvailableInterest = _productAvailableInterest(productStatus);
            totalAvailableInterest += (productAvailableInterest);
        }

        uint256 availableEarnings = _calculateEarnings(totalAvailableInterest);
        return referrerData.settledEarnings + availableEarnings;
    }

    function accruedEarnings(address referrer, uint256 productId) external view returns (uint256) {
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        if (!_existsProductStatus(referrerData, productId)) {
            return 0;
        }

        ProductStatus storage productStatus = referrerData.allProductStatus[referrerData.allProductStatusIndex[productId]];

        uint256 productAvailableInterest = _productAvailableInterest(productStatus);
        return _calculateEarnings(productAvailableInterest);
    }

    function claimEarnings(address referrer, address receiver, uint256[] memory productIdSet) external {
        ReferrerData storage referrerData = _referrerDataMapping[referrer];
        uint256 productEarnings = 0;
        for (uint256 i = 0; i < productIdSet.length; i++) {
            uint256 productId = productIdSet[i];
            if (_existsProductStatus(referrerData, productId)) {
                ProductStatus storage productStatus = referrerData.allProductStatus[referrerData.allProductStatusIndex[productId]];
                uint256 productAvailableInterest = _productAvailableInterest(productStatus);
                productEarnings = _calculateEarnings(productAvailableInterest);

                // update settledInterest
                productStatus.settledInterest += productAvailableInterest;
            }
        }

        uint256 claimableEarnings = referrerData.settledEarnings + productEarnings; 
        // set settledEarnings to 0
        referrerData.settledEarnings = 0;

        uint256 voucherId = longVoucher.mint(receiver, EARNINGS_SLOT_ID, claimableEarnings);
        emit Claimed(referrer, receiver, claimableEarnings, voucherId);
    }

    function _productAvailableInterest(ProductStatus storage productStatus) private view returns (uint256) {
        IProductCenter productCenter = IProductCenter(productStatus.productCenter);
        IProductCenter.ProductParameters memory productParameters = productCenter.getProductParameters(productStatus.productId);

        uint256 interest = productParameters.interestRate.calculate(productStatus.equities, productParameters.beginSubscriptionBlock, 
            productParameters.endSubscriptionBlock, productParameters.endSubscriptionBlock, block.number);
        
        return interest - productStatus.settledInterest;
    }

    /// implement IRecommendation

    function beforeEquitiesTransfer(
        address productCenter_,
        uint256 productId_,
        address from_,
        address to_,
        uint256 fromVoucherId_,
        uint256 toVoucherId_,
        uint256 value_
    ) external override {
        require(_msgSender() == productCenter_, "illegal caller");

        if (_existsRecommendation(from_)) {
            _tryTrackProduct(productCenter_, productId_, from_);
            _tryTrackVoucher(productCenter_, productId_, from_, fromVoucherId_);
        }

        if (_existsRecommendation(to_)) {
            _tryTrackProduct(productCenter_, productId_, to_);
            _tryTrackVoucher(productCenter_, productId_, to_, toVoucherId_);
        }
        
        value_;
    }

    function _tryTrackProduct(address productCenter, uint256 productId, address referral) private {
        // recommendation of referral
        RecommendationData memory recommendation = _referralRecommendations[referral];

        ReferrerData storage referrerData = _referrerDataMapping[recommendation.referrer];
        if (!_existsProductStatus(referrerData, productId)) {
            _addProductStatus(productCenter, referrerData, productId);
        }
    }

    function _addProductStatus(
        address productCenter,
        ReferrerData storage referrerData, 
        uint256 productId 
    ) private {
        uint256 index = referrerData.allProductStatus.length;

        // resize 
        referrerData.allProductStatus.push();
        ProductStatus storage productStatus = referrerData.allProductStatus[index];
        productStatus.productCenter = productCenter;
        productStatus.productId = productId;
        referrerData.allProductStatusIndex[productId] = index;
    }

    function _tryTrackVoucher(address productCenter, uint256 productId, address referral, uint256 voucherId) private {
        // recommendation of referral
        RecommendationData memory recommendation = _referralRecommendations[referral];

        ReferrerData storage referrerData = _referrerDataMapping[recommendation.referrer];
        ProductStatus storage productStatus = referrerData.allProductStatus[referrerData.allProductStatusIndex[productId]];
        if (!productStatus.voucherTrackedFlag[voucherId] && longVoucher.existsToken(voucherId)) {
            IProductCenter.ProductParameters memory productParameters = IProductCenter(productCenter).getProductParameters(productId);

            uint256 voucherBalance = longVoucher.balanceOf(voucherId);
            // uint256 endBlock = MathUpgradeable.max(productParameters.endSubscriptionBlock, recommendation.atBlock);
            // 计算voucher自起息区块至推荐关系绑定区块期间的利息，当作已清算的利息
            uint256 interest = productParameters.interestRate.calculate(voucherBalance, productParameters.beginSubscriptionBlock, 
                productParameters.endSubscriptionBlock, productParameters.endSubscriptionBlock, recommendation.atBlock);

            productStatus.voucherTrackedFlag[voucherId] = true;
            productStatus.equities += voucherBalance;
            productStatus.settledInterest += interest;
        }
    }

    function afterEquitiesTransfer(
        address productCenter_,
        uint256 productId_,
        address from_,
        address to_,
        uint256 fromVoucherId_,
        uint256 toVoucherId_,
        uint256 value_
    ) external override {
        require(_msgSender() == productCenter_, "illegal caller");

        if (_existsRecommendation(from_) 
            && _existsRecommendation(to_) 
            &&  _referralRecommendations[from_].referrer == _referralRecommendations[to_].referrer) {
            return;
        }

        IProductCenter.ProductParameters memory productParameters = IProductCenter(productCenter_).getProductParameters(productId_);
        if (_existsRecommendation(from_)) {
            RecommendationData memory recommendation = _referralRecommendations[from_];
            ReferrerData storage referrerData = _referrerDataMapping[recommendation.referrer];
            ProductStatus storage productStatus = referrerData.allProductStatus[referrerData.allProductStatusIndex[productId_]];

            uint256 interest = productParameters.interestRate.calculate(value_, productParameters.beginSubscriptionBlock, 
                productParameters.endSubscriptionBlock, productParameters.endSubscriptionBlock, block.number);
            if (interest < productStatus.settledInterest) {
                productStatus.settledInterest -= interest;
            } else {
                productStatus.settledInterest = 0;
                referrerData.settledEarnings = _calculateEarnings(interest - productStatus.settledInterest);
            }
            productStatus.equities -= value_;
        }

        if (_existsRecommendation(to_)) {
            RecommendationData memory recommendation = _referralRecommendations[to_];
            ReferrerData storage referrerData = _referrerDataMapping[recommendation.referrer];
            ProductStatus storage productStatus = referrerData.allProductStatus[referrerData.allProductStatusIndex[productId_]];

            uint256 interest = productParameters.interestRate.calculate(value_, productParameters.beginSubscriptionBlock, 
                productParameters.endSubscriptionBlock, productParameters.endSubscriptionBlock, block.number);
            
            productStatus.equities += value_;
            productStatus.settledInterest += interest;
            productStatus.voucherTrackedFlag[toVoucherId_] = true;
        }

        fromVoucherId_;
    }

    function _existsRecommendation(address referral) private view returns (bool) {
        return _referralRecommendations[referral].referrer != address(0);
    }

    function _existsProductStatus(ReferrerData storage referrerData, uint256 productId) private view returns (bool) {
        return referrerData.allProductStatus[referrerData.allProductStatusIndex[productId]].productId == productId;
    }

    function _calculateEarnings(uint256 interest) private view returns (uint256) {
        return interest * referrerEarningsRatioMantissa / MANTISSA_ONE;
    }

    /// implement ISlotManager

    function beforeValueTransfer(
        address from_,
        address to_,
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 slot_,
        uint256 value_
    ) external pure override {
        // require(_msgSender() == address(longVoucher), "illegal caller");

        // if (slot_ == QUALIFICATION_SLOT_ID) {
        //     // qualification can only be transferred as whole
        //     if (fromTokenId_ != 0 && toTokenId_ != 0) {
        //         require(fromTokenId_ == toTokenId_, "illegal transfer");
        //     }
        // }

        from_;
        to_;
        fromTokenId_;
        toTokenId_;
        slot_;
        value_;
    }

    function afterValueTransfer(
        address from_,
        address to_,
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 slot_,
        uint256 value_
    ) external override {
        require(_msgSender() == address(longVoucher), "illegal caller");

        if (slot_ == QUALIFICATION_SLOT_ID) {
            if (from_ != address(0)) {
                _referrerQualification[from_]--;
                if (_referrerQualification[from_] == 0) {
                    delete _referrerQualification[from_];
                }
            }

            if (to_ != address(0)) {
                _referrerQualification[from_]++;
            }
        }

        fromTokenId_;
        toTokenId_;
        value_;
    }
}