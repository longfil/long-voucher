// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IFilForwarder {
    function forward(bytes calldata destination) external payable;
}