// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../IProductCenter.sol";

contract LongVoucherHelper {

    ILongVoucher public longVoucher;

    constructor(address longVoucher_) {
        require(longVoucher_ != address(0), "zero address");

        longVoucher = ILongVoucher(longVoucher_);
    }

    function isSlotManager(address slotManager) external view returns (bool) {
        uint256 slotManagerCount = longVoucher.slotManagerCount(); 

        for (uint256 i = 0; i < slotManagerCount; i ++) {
            if (slotManager == longVoucher.slotManagerByIndex(i)) {
                return true;
            }
        }

        return false;
    }

    function allSlotManagers() external view returns (address[] memory) {
        uint256 slotManagerCount = longVoucher.slotManagerCount(); 

        address[] memory slotManagers = new address[](slotManagerCount);
        for (uint256 i = 0; i < slotManagerCount; i ++) {
            slotManagers[i] = longVoucher.slotManagerByIndex(i);
        }

        return slotManagers;
    }

    function managerOfToken(uint256 tokenId) public view returns (address) {
        return longVoucher.managerOf(longVoucher.slotOf(tokenId));
    }

    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 balance = longVoucher.balanceOf(owner);

        uint256 counter = balance;
        uint256[] memory tokens = new uint256[](balance);
        for (uint256 i = 0; i < balance; i ++) {
            tokens[--counter] = longVoucher.tokenOfOwnerByIndex(owner, i);
        }

        return tokens;
    }

    function tokensOfOwnerBySlot(address owner, uint256 slot) external view returns (uint256[] memory) {
        uint256 balance = longVoucher.balanceOf(owner);

        uint256 counter;
        for (uint256 i = 0; i < balance; i ++) {
            uint256 tokenId = longVoucher.tokenOfOwnerByIndex(owner, i);
            if (slot == longVoucher.slotOf(tokenId)) {
                counter++;
            }
        }

        uint256[] memory tokens = new uint256[](counter);
        for (uint256 i = 0; i < balance; i ++) {
            uint256 tokenId = longVoucher.tokenOfOwnerByIndex(owner, i);
            if (slot == longVoucher.slotOf(tokenId)) {
                tokens[--counter] = tokenId;
            }
        }

        return tokens;
    }

    function tokensOfOwnerBySlotManager(address owner, address slotManager) external view returns (uint256[] memory) {
        uint256 balance = longVoucher.balanceOf(owner);

        uint256 counter;
        for (uint256 i = 0; i < balance; i ++) {
            uint256 tokenId = longVoucher.tokenOfOwnerByIndex(owner, i);
            if (slotManager == managerOfToken(tokenId)) {
                counter++;
            }
        }

        uint256[] memory tokens = new uint256[](counter);
        for (uint256 i = 0; i < balance; i ++) {
            uint256 tokenId = longVoucher.tokenOfOwnerByIndex(owner, i);
            if (slotManager == managerOfToken(tokenId)) {
                tokens[--counter] = tokenId;
            }
        }

        return tokens;
    }
}

