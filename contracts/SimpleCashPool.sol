// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./ICashPool.sol";
import "./ICashPoolConsumer.sol";
import "./IFilForwarder.sol";
import "./ILongVoucher.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@solvprotocol/erc-3525/IERC721ReceiverUpgradeable.sol";

contract SimpleCashPool is Ownable2StepUpgradeable, ICashPool, IERC721ReceiverUpgradeable {

    struct ProductState {
        uint256 productId;
        uint256 redeemedEquities;
        uint256 redeemedAmount;
        uint256[5] __gap__;
    }

    /// storage

    ILongVoucher public longVoucher;
    IFilForwarder public filForwarder;

    // all supported productId
    ProductState[] private _allProducts;

    // productId => index in _allProducts
    mapping(uint256 => uint256) private _allProductsIndex;

    /// events
    event Recharge(address from, uint256 amount);
    event AddedProduct(uint256 indexed productId);
    event RemovedProduct(uint256 indexed productId, uint256 redeemedEquities, uint256 redeemedAmount);
    event Redemption(uint256 indexed productId, uint256 indexed voucherId, uint256 equities, uint256 amount);

    function initialize(
        address longVoucher_, 
        address filForwarder_,
        address initialOwner_
    ) public initializer {
        require(longVoucher_ != address(0), "zero address");
        require(filForwarder_ != address(0), "zero address");
        require(initialOwner_ != address(0), "zero address");

        longVoucher = ILongVoucher(longVoucher_);
        filForwarder = IFilForwarder(filForwarder_);

        // set up owner
        _transferOwnership(initialOwner_);
    }

    // The receive function
    receive() external payable {
        emit Recharge(msg.sender, msg.value);
    }

    // implement IERC721ReceiverUpgradeable
    function onERC721Received(
        address _operator, 
        address _from, 
        uint256 _tokenId, 
        bytes calldata _data
    ) external returns(bytes4) {
        _operator;
        _from;

        redeemInternal(_tokenId, _data);
        return type(IERC721ReceiverUpgradeable).interfaceId;
    }

    /// view functions

    function productCount() public view returns (uint256) {
        return _allProducts.length;
    }

    function productIdByIndex(uint256 index) external view returns (uint256) {
        require(index < productCount(), "index exceeds");
        return _allProducts[index].productId;
    }

    function isSupported(uint256 productId) public view returns (bool) {
        return _existsProduct(productId);
    }

    function getRedeemedEquities(uint256 productId) external view returns (uint256) {
        require(_existsProduct(productId), "unsupported product");

        return _allProducts[_allProductsIndex[productId]].redeemedEquities;
    }

    function getRedeemedAmount(uint256 productId) external view returns (uint256) {
        require(_existsProduct(productId), "unsupported product");

        return _allProducts[_allProductsIndex[productId]].redeemedAmount;
    }

    function getCash() public view returns (uint256) {
        return address(this).balance;
    }

    /// implement ICashPool
    function redeem(uint256 voucherId, bytes memory receiver) external override {
        require(receiver.length > 0, "zero address");
        require(longVoucher.ownerOf(voucherId) == _msgSender(), "not owner");

        redeemInternal(voucherId, receiver);
    }

    function redeemInternal(uint256 voucherId, bytes memory receiver) private {
        uint256 productId = longVoucher.slotOf(voucherId);
        require(isSupported(productId), "unsupported product");

        ICashPoolConsumer consumer = ICashPoolConsumer(longVoucher.managerOf(productId));
        require(consumer.isRedeemable(voucherId), "not redeemable");

        uint256 amount = consumer.getRedeemableAmount(voucherId);
        require(getCash() >= amount, "insufficient balance");

        uint256 equities = longVoucher.balanceOf(voucherId);

        // reference ProductState 
        ProductState storage product = _allProducts[_allProductsIndex[productId]];
        product.redeemedEquities += equities;
        product.redeemedAmount += amount;

        // burn voucher
        longVoucher.burn(voucherId);

        // send Fil
        filForwarder.forward{value: amount}(receiver);

        emit Redemption(productId, voucherId, equities, amount);
    }

    /// admin functions

    function addProduct(uint256 productId) external onlyOwner {
        require(!_existsProduct(productId), "already supported");

        // test valid slot
        longVoucher.managerOf(productId);

        uint256 index = _allProducts.length;

        // update storage
        _allProducts.push();
        _allProductsIndex[productId] = index;

        ProductState storage product = _allProducts[index];
        product.productId = productId;

        emit AddedProduct(productId);
    }

    function removeProduct(uint256 productId) external onlyOwner {
        require(_existsProduct(productId), "unsupported product");

        uint256 lastProductIndex = _allProducts.length - 1;
        ProductState memory lastProduct = _allProducts[lastProductIndex];

        uint256 targetIndex = _allProductsIndex[productId];
        ProductState memory targetProduct = _allProducts[targetIndex];

        _allProducts[targetIndex] = lastProduct;
        _allProductsIndex[lastProduct.productId] = targetIndex;

        delete _allProductsIndex[productId];
        _allProducts.pop();

        emit RemovedProduct(productId, targetProduct.redeemedEquities, targetProduct.redeemedAmount);
    }


    /// internal functions
    
    function _existsProduct(uint256 productId) private view returns (bool) {
        return _allProducts.length > 0 && _allProducts[_allProductsIndex[productId]].productId == productId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[46] private __gap;
}