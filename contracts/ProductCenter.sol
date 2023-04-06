// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./Errors.sol";
import "./ICashPool.sol";
import "./IInterestRate.sol";
import "./ILongVoucher.sol";
import "./IProductCenter.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract ProductCenter is AccessControlUpgradeable, IProductCenter {
    /// constants
    bytes32 public constant ADMIN_ROLE = keccak256("admin");
    bytes32 public constant OPERATOR_ROLE = keccak256("operator");
    bytes32 public constant CASHIER_ROLE = keccak256("cashier");

    struct SubscriptionData {
        uint256 atBlock;
        address subscriber;
        uint256 principal;
        uint256 voucherId;
        // gap
        uint256[10] __gap;
    }

    struct ProductData {
        uint256 productId;
        ProductParameters parameters;
        uint256 totalFunds;
        uint256 totalLoans;
        // gap
        uint256[10] __gap;
    }

    /// storage

    ILongVoucher public longVoucher;

    // all products
    ProductData[] private _allProducts;

    // productId => index in _allProducts
    mapping(uint256 => uint256) private _allProductsIndex;

    // subscriber => productId => subscriptions
    mapping(address => mapping(uint256 => SubscriptionData)) private _subscriptions;

    /// events
    event ProductCreated(uint256 indexed productId, ProductParameters parameters, address operator);

    event InterestRateChanged(uint256 indexed productId, address oldInterestRate, address newInterestRate);

    event Subscribe(uint256 indexed productId, address subscriber, uint256 principal, uint256 voucherId);

    event CancelSubscription(uint256 indexed productId, address subscriber, uint256 principal, uint256 voucherId);

    event Claimed(uint256 indexed productId, address subscriber, address receiver, uint256 voucherId);

    event OfferLoans(uint256 indexed productId, address receiver, uint256 amount, address cashier);

    event CashPoolChanged(uint256 indexed productId, address oldCashPool, address newCashPool);

    /**
     * initialize method, called by proxy
     */
    function initialize(
        address longVoucher_,
        address initialAdmin_
    ) public initializer {
        longVoucher = ILongVoucher(longVoucher_);

        // call super
        AccessControlUpgradeable.__AccessControl_init();

        // grant roles
        _grantRole(ADMIN_ROLE, initialAdmin_);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(OPERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(CASHIER_ROLE, ADMIN_ROLE);
    }

    /// view functions
    function productCount() public view override returns (uint256) {
        return _allProducts.length;
    }

    function productByIndex(
        uint256 index_
    ) external view override returns (uint256) {
        require(index_ < productCount(), Errors.INDEX_EXCEEDS);
        return _allProducts[index_].productId;
    }

    function getProductParameters(
        uint256 productId
    ) external view override returns (ProductParameters memory parameters) {
        _requireExistsProduct(productId);
        return _allProducts[_allProductsIndex[productId]].parameters;
    }

    function getTotalFunds(
        uint256 productId
    ) external view override returns (uint256) {
        _requireExistsProduct(productId);
        return _allProducts[_allProductsIndex[productId]].totalFunds;
    }

    function getTotalLoans(
        uint256 productId
    ) external view override returns (uint256) {
        _requireExistsProduct(productId);
        return _allProducts[_allProductsIndex[productId]].totalLoans;
    }

    function isSubscriber(uint256 productId, address subscriber) public view override returns (bool) {
        _requireExistsProduct(productId);
        return _existsSubscription(productId, subscriber);
    }

    function getSubscription(uint256 productId, address subscriber) external view override returns (Subscription memory subscription) {
        _requireIsSubscriber(productId, subscriber);

        SubscriptionData memory subscriptionData = _subscriptions[subscriber][productId];

        subscription.subscriber = subscriptionData.subscriber;
        subscription.atBlock = subscriptionData.atBlock;
        subscription.principal = subscriptionData.principal;
        subscription.voucherId = subscriptionData.voucherId;
    }

   function isRedeemable(
        uint256 voucherId
    ) external view override returns (bool) {
        uint256 productId = ILongVoucher(longVoucher).slotOf(voucherId);
        _requireExistsProduct(productId);

        ProductParameters memory parameters = _allProducts[_allProductsIndex[productId]].parameters;
        return _isRedeemable(parameters);
    }

    function voucherInterest(
        uint256 voucherId
    ) public view override returns (uint256) {
        uint256 productId = ILongVoucher(longVoucher).slotOf(voucherId);
        _requireExistsProduct(productId);

        ProductParameters memory parameters = _allProducts[_allProductsIndex[productId]].parameters;
        if (_isInSubscriptionStage(parameters)) {
            return 0; 
        }

        return
            IInterestRate(parameters.interestRate).calculate(
                ILongVoucher(longVoucher).balanceOf(voucherId),
                parameters.beginSubscriptionBlock,
                parameters.endSubscriptionBlock
            );
    }

    function voucherPrincipalAndInterest(uint256 voucherId) external view override returns (uint256) {
        uint256 interest = voucherInterest(voucherId);
        return ILongVoucher(longVoucher).balanceOf(voucherId) + interest;
    }

    function productInterest(uint256 productId) public view override returns (uint256) {
        _requireExistsProduct(productId);

        ProductParameters memory parameters = _allProducts[_allProductsIndex[productId]].parameters;
        if (_isInSubscriptionStage(parameters)) {
            return 0; 
        }

        return
            IInterestRate(parameters.interestRate).calculate(
                ILongVoucher(longVoucher).balanceOfSlot(productId),
                parameters.beginSubscriptionBlock,
                parameters.endSubscriptionBlock
            );
    }

    function productPrincipalAndInterest(uint256 productId) external view override returns (uint256) {
        uint256 interest = productInterest(productId);
        return ILongVoucher(longVoucher).balanceOfSlot(productId) + interest;
    }

    /// admin functions

    function setInterestRate(
        uint256 productId,
        address interestRate_
    ) external onlyRole(OPERATOR_ROLE) {
        _requireExistsProduct(productId);
        require(interestRate_ != address(0), Errors.ZERO_ADDRESS);

        ProductParameters storage parameters = _allProducts[_allProductsIndex[productId]].parameters;
        require(
            block.number < parameters.beginSubscriptionBlock || block.number >= parameters.endSubscriptionBlock,
            Errors.INVALID_PRODUCT_STAGE
        );

        address oldInterestRate = parameters.interestRate;
        parameters.interestRate = interestRate_;

        emit InterestRateChanged(productId, oldInterestRate, interestRate_);
    }

    function setCashPool(uint256 productId, address cashPool_) external onlyRole(OPERATOR_ROLE) {
        _requireExistsProduct(productId);
        require(cashPool_ != address(0), Errors.ZERO_ADDRESS);

        ProductParameters storage parameters = _allProducts[_allProductsIndex[productId]].parameters;
        address oldCashPool = parameters.cashPool;
        parameters.cashPool = cashPool_;

        emit CashPoolChanged(productId, oldCashPool, cashPool_);
    }

    /// state functions

    function create(
        uint256 productId,
        ProductParameters memory parameters
    ) public onlyRole(OPERATOR_ROLE) {
        require(!_existsProduct(productId), Errors.DUPLICATED_PRODUCT_ID);

        require(parameters.totalQuota > 0, Errors.BAD_TOTALQUOTA);
        require(parameters.totalQuota >= parameters.minSubscriptionAmount, Errors.BAD_MINSUBSCRIPTIONAMOUNT);
        require(parameters.beginSubscriptionBlock >= block.number, Errors.BAD_BEGINSUBSCRIPTIONBLOCK);
        require(parameters.endSubscriptionBlock > parameters.beginSubscriptionBlock, Errors.BAD_ENDSUBSCRIPTIONBLOCK);
        require(parameters.interestRate != address(0), Errors.ZERO_ADDRESS);

        // claim slot via mint zero amount,
        ILongVoucher(longVoucher).mint(address(this), productId, 0);

        // change state
        // resize _allProducts
        _allProducts.push();

        ProductData storage product = _allProducts[_allProducts.length - 1];
        product.productId = productId;
        product.parameters.totalQuota = parameters.totalQuota;
        product.parameters.minSubscriptionAmount = parameters.minSubscriptionAmount;
        product.parameters.beginSubscriptionBlock = parameters.beginSubscriptionBlock;
        product.parameters.endSubscriptionBlock = parameters.endSubscriptionBlock;
        product.parameters.minHoldingDuration = parameters.minHoldingDuration;
        product.parameters.interestRate = parameters.interestRate;
        product.parameters.cashPool = parameters.cashPool;

        _allProductsIndex[productId] = _allProducts.length - 1;

        // emit events
        emit ProductCreated(productId, parameters, _msgSender());
        emit InterestRateChanged(productId, address(0), parameters.interestRate);
        emit CashPoolChanged(productId, address(0), parameters.cashPool);
    }

    function subscribe(
        uint256 productId
    ) public payable returns (uint256 voucherId) {
        _requireExistsProduct(productId);

        address subscriber = _msgSender();
        uint256 principal = msg.value;

        // ref ProductData
        ProductData storage product = _allProducts[_allProductsIndex[productId]];
        ProductParameters memory parameters = product.parameters;

        // check whether subscription is opening
        _requireInSubscriptionStage(parameters);
        require(product.totalFunds + principal <= parameters.totalQuota, Errors.EXCEEDS_TOTALQUOTA);

        // if additional subscription, re mint voucher
        if (_existsSubscription(productId, subscriber)) {
            SubscriptionData storage subscription = _subscriptions[subscriber][productId];

            uint256 oldVoucherId = subscription.voucherId;
            uint256 oldPrincipalAndInterest = ILongVoucher(longVoucher).balanceOf(oldVoucherId);
            uint256 addedInterestDuringSubscription = IInterestRate(parameters.interestRate)
                .calculate(principal, parameters.beginSubscriptionBlock, parameters.endSubscriptionBlock);
            uint256 newPrincipalAndInterest = oldPrincipalAndInterest + principal + addedInterestDuringSubscription;

            // burn old voucher
            ILongVoucher(longVoucher).burn(oldVoucherId);
            // mint new voucher
            voucherId = ILongVoucher(longVoucher).mint(address(this), productId, newPrincipalAndInterest);

            // update state
            product.totalFunds += principal;
            subscription.atBlock = block.number;
            subscription.principal += principal;
            subscription.voucherId = voucherId;

            emit Subscribe(productId, subscriber, subscription.principal, voucherId);
        } else {
            require(principal >= parameters.minSubscriptionAmount, Errors.LESS_THAN_MINSUBSCRIPTIONAMOUNT);

            uint256 interestDuringSubscription = IInterestRate(parameters.interestRate)
                .calculate(principal, parameters.beginSubscriptionBlock, parameters.endSubscriptionBlock);
            uint256 principalAndInterest = principal + interestDuringSubscription;

            // mint voucher
            voucherId = ILongVoucher(longVoucher).mint(address(this), productId, principalAndInterest);

            // update states
            product.totalFunds += principal;

            SubscriptionData storage subscription = _subscriptions[subscriber][productId];
            subscription.atBlock = block.number;
            subscription.subscriber = subscriber;
            subscription.principal = principal;
            subscription.voucherId = voucherId;

            emit Subscribe(productId, subscriber, subscription.principal, voucherId);
        }
    }

    function cancelSubscription(
        uint256 productId,
        uint256 amount,
        address receiver
    ) external returns (uint256 newVoucherId) {
        _requireIsSubscriber(productId, _msgSender());
        require(receiver != address(0), Errors.ZERO_ADDRESS);

        // ref ProductData
        ProductData storage product = _allProducts[_allProductsIndex[productId]];
        ProductParameters memory parameters = product.parameters;

        // check whether subscription is opening
        _requireInSubscriptionStage(parameters);

        address subscriber = _msgSender();
        SubscriptionData storage subscription = _subscriptions[subscriber][productId];

        require(amount <= subscription.principal, Errors.INSUFFICIENT_BALANCE);

        // hold old values
        uint256 oldPrincipal = subscription.principal;
        uint256 oldVoucherId = subscription.voucherId;

        uint256 newPrincipal = subscription.principal - amount;
        // redeem all
        if (newPrincipal == 0) {
            // burn voucher
            ILongVoucher(longVoucher).burn(oldVoucherId);

            // update state
            product.totalFunds -= oldPrincipal;
            delete _subscriptions[subscriber][productId];

            // send Fil
            (bool sent, bytes memory _data) = receiver.call{value: oldPrincipal}("");
            require(sent, Errors.SEND_ERROR);

            _data;

            emit CancelSubscription(productId, subscriber, oldPrincipal, oldVoucherId);
        } else {
            require(newPrincipal >= parameters.minSubscriptionAmount, Errors.LESS_THAN_MINSUBSCRIPTIONAMOUNT);

            // calculate new interest during subscription
            uint256 interestDuringSubscription = IInterestRate(parameters.interestRate)
                .calculate(newPrincipal, parameters.beginSubscriptionBlock, parameters.endSubscriptionBlock);
            uint256 principalAndInterest = newPrincipal + interestDuringSubscription;

            // burn old voucher
            ILongVoucher(longVoucher).burn(oldVoucherId);
            // mint new voucher
            newVoucherId = ILongVoucher(longVoucher).mint(address(this), productId, principalAndInterest);

            // update state
            product.totalFunds -= amount;
            subscription.atBlock = block.number;
            subscription.principal = newPrincipal;
            subscription.voucherId = newVoucherId;

            // send Fil
            (bool sent, bytes memory _data) = receiver.call{value: amount}("");
            require(sent, Errors.SEND_ERROR);

            _data;

            emit CancelSubscription(productId, subscriber, oldPrincipal, oldVoucherId);
            emit Subscribe(productId, subscriber, newPrincipal, newVoucherId);
        }
    }

    function claim(uint256 productId, address receiver) external returns (uint256) {
        _requireIsSubscriber(productId, _msgSender());
        require(receiver != address(0), Errors.ZERO_ADDRESS);

        // ref ProductData
        ProductData memory product = _allProducts[_allProductsIndex[productId]];

        // check
        _requirePostSubscriptionStage(product.parameters);

        address subscriber = _msgSender();
        SubscriptionData memory subscription = _subscriptions[subscriber][productId];
        _requireEscrowVoucher(subscription.voucherId);

        // transfer voucher to subscriber
        ILongVoucher(longVoucher).safeTransferFrom(address(this), receiver, subscription.voucherId);

        emit Claimed(productId, subscriber, receiver, subscription.voucherId);

        return subscription.voucherId;
    }

    function redeem(uint256 productId, address receiver) external returns (uint256) {
        _requireIsSubscriber(productId, _msgSender());
        require(receiver != address(0), Errors.ZERO_ADDRESS);

        ProductData memory product = _allProducts[_allProductsIndex[productId]];
        ProductParameters memory parameters = product.parameters;

        // check
        require(_isRedeemable(parameters) && address(parameters.cashPool) != address(0), Errors.CAN_NOT_REDEEM_AT_PRESENT);

        address subscriber = _msgSender();
        SubscriptionData memory subscription = _subscriptions[subscriber][productId];
        _requireEscrowVoucher(subscription.voucherId);

        ILongVoucher(longVoucher).approve(address(parameters.cashPool), subscription.voucherId);
        ICashPool(parameters.cashPool).redeem(subscription.voucherId, receiver);

        return subscription.voucherId;
    }

    function lend(
        uint256 productId,
        uint256 amount,
        address receiver
    ) external onlyRole(CASHIER_ROLE) {
        _requireExistsProduct(productId);
        require(receiver != address(0), Errors.ZERO_ADDRESS);

        ProductData storage product = _allProducts[_allProductsIndex[productId]];

        // check whether subscription is closed
        _requirePostSubscriptionStage(product.parameters);
        require(product.totalLoans + amount <= product.totalFunds, Errors.INSUFFICIENT_BALANCE);

        // add to total loans
        product.totalLoans += amount;

        // send Fil
        (bool sent, bytes memory _data) = receiver.call{value: amount}("");
        require(sent, Errors.SEND_ERROR);

        _data;

        emit OfferLoans(productId, receiver, amount, _msgSender());
    }

    /// internal functions

    function _requireExistsProduct(uint256 productId) private view {
        require(_existsProduct(productId), Errors.PRODUCT_NOT_EXISTS);
    }

    function _existsProduct(uint256 productId) private view returns (bool) {
        return _allProducts.length > 0 && _allProducts[_allProductsIndex[productId]].productId == productId;
    }

    function _requireInSubscriptionStage(
        ProductParameters memory parameters
    ) private view {
        require(_isInSubscriptionStage(parameters), Errors.INVALID_PRODUCT_STAGE);
    }

    function _isInSubscriptionStage(
        ProductParameters memory parameters
    ) private view returns (bool) {
        return block.number >= parameters.beginSubscriptionBlock && block.number < parameters.endSubscriptionBlock;
    }

    function _requirePostSubscriptionStage(
        ProductParameters memory parameters
    ) private view {
        require(block.number >= parameters.endSubscriptionBlock, Errors.INVALID_PRODUCT_STAGE);
    }

    function _isRedeemable(
        ProductParameters memory parameters
    ) private view returns (bool) {
        return block.number >= parameters.endSubscriptionBlock + parameters.minHoldingDuration;
    }

    function _requireIsSubscriber(
        uint256 productId,
        address subscriber
    ) private view {
        require(isSubscriber(productId, subscriber), Errors.NOT_SUBSCRIBER);
    }

    function _existsSubscription(
        uint256 productId,
        address subscriber
    ) private view returns (bool) {
        return _subscriptions[subscriber][productId].subscriber == subscriber;
    }

    function _requireEscrowVoucher(
        uint256 voucherId
    ) private view {
        require(ILongVoucher(longVoucher).ownerOf(voucherId) == address(this), Errors.NOT_ESCROW_VOUCHER);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[46] private __gap;
}
