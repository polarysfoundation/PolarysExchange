// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Order, Auction} from "../lib/Structs.sol";

interface IPolarysExchange {
    function executeSellOrCancel(
        Order calldata order,
        bytes calldata _signature
    ) external;

    function executeBuy(
        Order calldata order,
        bytes32 orderHash,
        bytes calldata _signature
    ) external payable;

    function executeBuyWithERC20(
        Order calldata order,
        bytes32 orderHash,
        bytes calldata _signature
    ) external;

    function executeAuctionWithSignature(
        Auction calldata auction,
        bytes calldata _signature
    ) external;

    function sendBid(
        Auction calldata auction,
        bytes32 orderHash,
        bytes calldata _signature
    ) external payable;

    function sendBidWithERC20(
        Auction calldata auction,
        bytes32 orderHash,
        bytes calldata _signature
    ) external;
}
