// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IProductCenterDescriptor {
    struct BasicInfo {
        string name;
        string desc;
        string link;
    }

    function getProductCenterInfo(address productCenter) external view returns (BasicInfo memory);

    function getProductInfo(uint256 productId) external view returns (BasicInfo memory);
}