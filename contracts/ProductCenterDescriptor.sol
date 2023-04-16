// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./IInterestRate.sol";
import "./IProductCenter.sol";
import "./ILongVoucher.sol";
import "./ILongVoucherMetadataProvider.sol";
import "./utils/StringConverter.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

contract ProductCenterDescriptor is
    Ownable2StepUpgradeable,
    ILongVoucherMetadataProvider
{
    using StringConverter for address;
    using StringConverter for uint256;
    using StringConverter for bytes;

    struct BasicInfo {
        string name;
        string desc;
        string link;
    }

    ILongVoucher public longVoucher;

    // product center => product center info
    mapping(address => BasicInfo) private _productCenterBasics;

    // product id => product information
    mapping(uint256 => BasicInfo) private _productBasics;

    // product cneter => IVoucherSVG
    mapping(address => address) private _productCenterVoucherSVGs;

    // product id => IVoucherSVG
    mapping(uint256 => address) private _productVoucherSVGs;

    /// upgradeable initialize
    function initialize(
        address longVoucher_,
        address initialOwner_
    ) public initializer {
        require(longVoucher_ != address(0), "zero address");
        require(initialOwner_ != address(0), "zero address");

        // call super
        Ownable2StepUpgradeable.__Ownable2Step_init();

        // initialize
        longVoucher = ILongVoucher(longVoucher_);

        // initialize owner
        _transferOwnership(initialOwner_);
    }

    /// admin functions
    function setProductCenterInfo(address productCenter, BasicInfo memory basicInfo) external onlyOwner {
        _productCenterBasics[productCenter] = basicInfo;
    }

    function setProductInfo(uint256 productId, BasicInfo memory basicInfo) external onlyOwner {
        _productBasics[productId] = basicInfo;
    }

    function setProductCenterVoucherSVG(address productCenter, address voucherSVG_) external onlyOwner {
        require(voucherSVG_ != address(0), "zero address");

        _productCenterVoucherSVGs[productCenter] = voucherSVG_;
    }

    function setProductVoucherSVG(uint256 productId, address voucherSVG_) external onlyOwner {
        require(voucherSVG_ != address(0), "zero address");

        _productVoucherSVGs[productId] = voucherSVG_;
    }

    /// view functions
    function getProductCenterInfo(address productCenter) external view returns (BasicInfo memory) {
        return _productCenterBasics[productCenter];
    }

    function getProductInfo(uint256 productId) external view returns (BasicInfo memory) {
        return _productBasics[productId];
    }

    function getProductCenterVoucherSVG(address productCenter) public view returns (address) {
        return _productCenterVoucherSVGs[productCenter];
    }

    function getProductVoucherSVG(uint256 productId) public view returns (address) {
        return _productVoucherSVGs[productId];
    }

    function slotMetadata(
        uint256 productId
    ) external view override returns (LongVoucherMetadata memory metadata) {
        IProductCenter productCenter = IProductCenter(longVoucher.managerOf(productId));
        BasicInfo memory productCenterInfo = _productCenterBasics[address(productCenter)];

        BasicInfo memory productInfo = _productBasics[productId];
        IProductCenter.ProductParameters memory parameters = productCenter.getProductParameters(productId);

        metadata.name = productInfo.name;
        metadata.desc = productInfo.desc;
        metadata.link = bytes(productInfo.link).length > 0 ? productInfo.link : productCenterInfo.link;

        metadata.attributes[0] = productCenterNameAttribute(productCenterInfo.name);
        metadata.attributes[1] = productCenterContractAttribute(productCenter);
        metadata.attributes[2] = productStageAttribute(parameters);
    }

    function tokenMetadata(
        uint256 voucherId
    ) external view override returns (LongVoucherMetadata memory metadata) {
        uint256 productId = longVoucher.slotOf(voucherId);
        IProductCenter productCenter = IProductCenter(longVoucher.managerOf(productId));
        BasicInfo memory productCenterInfo = _productCenterBasics[address(productCenter)];

        IProductCenter.ProductParameters memory parameters = productCenter.getProductParameters(productId);
        BasicInfo memory productInfo = _productBasics[productId];

        metadata.name = string.concat(productInfo.name, "#", voucherId.toString());
        metadata.desc = metadata.name; // TODO: 凭单描述
        metadata.link = string.concat(productInfo.link, "/", voucherId.toString());

        metadata.attributes[0] = productCenterNameAttribute(productCenterInfo.name);
        metadata.attributes[1] = productCenterContractAttribute(productCenter);
        metadata.attributes[2] = productNameAttribute(productInfo);
        metadata.attributes[3] = productStageAttribute(parameters);
        metadata.attributes[4] = nowAPRAttribute(parameters, voucherId);
        metadata.attributes[5] = accumulatedInterestAttribute(productCenter, voucherId);
        metadata.attributes[6] = isRedeemableAttribute(productCenter, voucherId);
    }

    function voucherSVG(
        uint256 voucherId
    ) external view override returns (address) {
        uint256 productId = longVoucher.slotOf(voucherId);
        address productVoucherSVG = _productVoucherSVGs[productId];
        return productVoucherSVG == address(0) ? getProductCenterVoucherSVG(longVoucher.managerOf(productId)) : productVoucherSVG;
    }

    function productCenterNameAttribute(string memory productCenterName)
        private
        pure
        returns (Attribute memory attribute)
    {
        attribute = Attribute({
            name: "product_center",
            desc: "product center name",
            value: productCenterName
        });
    }

    function productCenterContractAttribute(IProductCenter productCenter)
        private
        pure
        returns (Attribute memory attribute)
    {
        attribute = Attribute({
            name: "product_center_contract",
            desc: "contract address of product center",
            value: address(productCenter).toString()
        });
    }

    // function productIdAttribute(
    //     uint256 productId
    // ) private pure returns (Attribute memory attribute) {
    //     attribute = Attribute({
    //         name: "product_id",
    //         desc: "product id",
    //         value: productId.toString()
    //     });
    // }

    function productNameAttribute(
        BasicInfo memory info
    ) private pure returns (Attribute memory attribute) {
        attribute = Attribute({
            name: "product_name",
            desc: "product name",
            value: info.name
        });
    }

    function productStageAttribute(
        IProductCenter.ProductParameters memory parameters
    ) private view returns (Attribute memory attribute) {
        attribute = Attribute({
            name: "product_stage",
            desc: "stage of product",
            value: getProductStage(parameters)
        });
    }

    function getProductStage(
        IProductCenter.ProductParameters memory parameters
    ) private view returns (string memory stage) {
        if (block.number < parameters.beginSubscriptionBlock) {
            stage = "PRE_SUBSCRIPTION";
        } else if (block.number < parameters.endSubscriptionBlock) {
            stage = "IN_SUBSCRIPTION";
        } else {
            stage = "POST_SUBSCRIPTION";
        }
    }

    function nowAPRAttribute(
        IProductCenter.ProductParameters memory parameters,
        uint256 voucherId
    ) private view returns (Attribute memory attribute) {
        uint256 principal = longVoucher.balanceOf(voucherId);
        string memory apr = IInterestRate(parameters.interestRate).nowAPR(
            principal, parameters.beginSubscriptionBlock, parameters.endSubscriptionBlock);
        attribute = Attribute({
            name: "APR",
            desc: "APR at present",
            value: apr
        });
    }

    function accumulatedInterestAttribute(
        IProductCenter productCenter,
        uint256 voucherId
    ) private view returns (Attribute memory attribute) {
        attribute = Attribute({
            name: "interests",
            desc: "accumulated interest",
            value: string(productCenter.voucherInterest(voucherId).uint2decimal(18).trim(16))
        });
    }

    function isRedeemableAttribute(
        IProductCenter productCenter,
        uint256 voucherId
    ) private view returns (Attribute memory attribute) {
        attribute = Attribute({
            name: "is_redeemable",
            desc: "redeemable or not at present",
            value: productCenter.isRedeemable(voucherId) ? "true" : "false"
        });
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
}