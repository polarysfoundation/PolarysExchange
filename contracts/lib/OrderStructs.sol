// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum AssetType {
    ERC721,
    ERC1155
}

enum Action {
    SELL,
    BUY,
    RESERVED_PRICE,
    AUCTION_BID,
    CLAIM,
    CANCEL
}
