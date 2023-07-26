// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Structs {
    struct ActiveSales {
        bool activeSaleExists;
    }

    struct Order {
        bytes32 orderId; // unique order ID
        address buyer; // Buyer
        address seller; // Seller owner of token
        uint256 price;
        address tokenAddress;
        address tokenCurrency;
        uint256 tokenId;
        uint256 orderEndTime;
        /*
         * 0: order created
         * 1: order accepted
         * 2: order canceled
         */
        uint8 status;
        uint256 nonce;
        bytes32 nonceKey;
    }

    struct Bid {
        bytes32 bidId;
        address taker;
        address bidder;
        uint256 amount;
        uint256 tokenId;
        address tokenAddress;
        address tokenCurrency;
        uint256 nonce;
        /*
         * 0: bid created
         * 1: bid accepted
         * 2: bid canceled
         */
        uint256 status;
        bytes32 nonceKey;
    }

    struct Auction {
        address highestBidder;
        uint256 highestBid;
        address tokenAddress;
        address seller;
        address tokenCurrency;
        bytes32 auctionId;
        uint256 endTime;
        uint256 reservedPrice;
        uint256 tokenId;
        /*
         * 0: auction created
         * 2: auction canceled
         * 3: auction started
         * 4: auction claimed
         */
        uint8 status;
        uint256 nonce;
        bytes32 nonceKey;
    }

    mapping(bytes32 => Order) public _order;
    mapping(bytes32 => Auction) public _auction;
    mapping(bytes32 => Bid) public _bid;
    mapping(address => mapping(uint256 => ActiveSales)) public isTokenSale;
}
