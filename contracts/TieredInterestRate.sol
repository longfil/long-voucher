// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./IInterestRate.sol";

contract TieredInterestRate is IInterestRate {
    uint constant SCALE = 1e36;

    // 30 secs per block
    uint256 public constant BLOCKS_PER_DAY = (24 * 3600) / 30;
    uint256 public constant BLOCKS_PER_YEAR = BLOCKS_PER_DAY * 365;

    // blocks of 120 days
    uint256 constant BLOCKS_120_DAYS = 120 * BLOCKS_PER_DAY; 
    // blocks of 240 days
    uint256 constant BLOCKS_240_DAYS= 240 * BLOCKS_PER_DAY; 
    // blocks of 360 days
    uint256 constant BLOCKS_360_DAYS= 360 * BLOCKS_PER_DAY; 

    // interest rate per block when holding duration < 120 days -- 6%
    uint256 constant BLOCK_RATE_HOLDING_LE_120 = 6 * SCALE / 100 / BLOCKS_PER_YEAR; 
    // interest rate per block when holding duration < 240 days -- 8%
    uint256 constant BLOCK_RATE_HOLDING_LE_240 = 8 * SCALE / 100 / BLOCKS_PER_YEAR; 
    // interest rate per block when holding duration < 360 days -- 10%
    uint256 constant BLOCK_RATE_HOLDING_LE_360 = 10 * SCALE / 100 / BLOCKS_PER_YEAR; 
    // interest rate per block when holding duration >= 360 days -- 12%
    uint256 constant BLOCK_RATE_HOLDING_GT_360 = 12 * SCALE / 100 / BLOCKS_PER_YEAR; 

    // interest rate in subscription stage
    uint256 constant BLOCK_RATE_SUBSCRIPTION = BLOCK_RATE_HOLDING_LE_120;

    function calculate(
        uint256 principal,
        uint256 beginSubscriptionBlock,
        uint256 endSubscriptionBlock
    ) external view override returns (uint256 interest) {
        require(endSubscriptionBlock - beginSubscriptionBlock <= BLOCKS_120_DAYS, "illegal block range");

        // pre subscription
        if (block.number < beginSubscriptionBlock) {
            interest = 0;
        }
        // in subscription stage
        else if (block.number < endSubscriptionBlock) {
            uint256 blockDelta = endSubscriptionBlock - block.number;
            interest = principal * BLOCK_RATE_SUBSCRIPTION * blockDelta / SCALE; 
        } 
        // post subscription stage
        else {
            uint256 holdingDuration = block.number - endSubscriptionBlock;
            if (holdingDuration <= BLOCKS_120_DAYS) {
                interest = principal * BLOCK_RATE_HOLDING_LE_120 * holdingDuration / SCALE;
            } else if  (holdingDuration <= BLOCKS_240_DAYS) {
                interest = principal * BLOCK_RATE_HOLDING_LE_240 * holdingDuration / SCALE;
            } else if  (holdingDuration <= BLOCKS_360_DAYS) {
                interest = principal * BLOCK_RATE_HOLDING_LE_360 * holdingDuration / SCALE;
            } else {
                interest = principal * BLOCK_RATE_HOLDING_GT_360 * holdingDuration / SCALE;
            }
        }
    }
}
