// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Structs.sol";
import "./Variables.sol";
import "./OrderUtils.sol";
import "./TransferHelper.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BidFunctions is
    Structs,
    Variables,
    OrderUtils,
    TransferHelper,
    ReentrancyGuard
{
    using SafeMath for uint256;

    event MakeABid(
        address maker,
        uint256 tokenId,
        address tokenAddress,
        uint256 bidAmount,
        bytes32 bidId
    );

    event CancellBid(
        address maker,
        uint256 tokenId,
        address tokenAddress,
        bytes32 bidId
    );

    event UpdateBid(
        address tokenAddress,
        uint256 tokenId,
        uint256 newPrice,
        bytes32 bidId
    );

    event TakeBid(
        address tokenAddress,
        uint256 tokenId,
        address maker,
        address taker,
        bytes32 bidId
    );

    /* Working */
    function _makeABid(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _amount,
        bytes memory _signature
    ) external payable noZero(_amount) nonReentrant {
        bytes32 bidId = generateId(_tokenId, _tokenAddress);
        address tokenOwner = IERC721(_tokenAddress).ownerOf(_tokenId);

        require(
            msg.sender != tokenOwner,
            "Bid Functions: You can't make a bid"
        );

        require(
            msg.sender != IERC721(_tokenAddress).ownerOf(_tokenId),
            "Bid Functions: You can't make a bid"
        );

        require(
            tokenOwner != address(0),
            "Bid Functions: token does not exist"
        );

        require(
            msg.value == _amount,
            "Bid Functions: Insufient amount to transfer"
        );

        bytes32 nonceKey = generateNonce(bidId);

        uint256 nonce = getNonce(nonceKey);
        address tokenCurrency = address(0);

        bytes32 messageHash = generateOrderHash(
            _amount,
            _tokenId,
            _tokenAddress,
            tokenCurrency,
            0
        );

        require(
            verifySignature(messageHash, _signature, msg.sender),
            "Bid Functions: Invalid signature"
        );

        Bid storage bid = _bid[bidId];
        bid.bidId = bidId;
        bid.bidder = msg.sender;
        bid.amount = _amount;
        bid.tokenId = _tokenId;
        bid.tokenAddress = _tokenAddress;
        bid.tokenCurrency = tokenCurrency;
        bid.nonce = nonce;
        bid.status = 0;
        bid.taker = address(0);
        bid.nonceKey = nonceKey;

        emit MakeABid(msg.sender, _tokenId, _tokenAddress, _amount, bidId);
    }

    /* Working */
    function makeABid(
        address _tokenAddress,
        address _tokenCurrency,
        uint256 _tokenId,
        uint256 _amount,
        bytes memory _signature
    ) external noZero(_amount) nonReentrant {
        address maker = msg.sender;
        bytes32 bidId = generateId(_tokenId, _tokenAddress);
        address tokenOwner = IERC721(_tokenAddress).ownerOf(_tokenId);

        require(maker != tokenOwner, "Bid Functions: You can't make a bid");

        require(
            _tokenCurrency != address(0),
            "Bid Functions: Invalid Transaction"
        );

        bytes32 nonceKey = generateNonce(bidId);

        uint256 nonce = getNonce(nonceKey);
        address tokenCurrency = _tokenCurrency;

        bytes32 messageHash = generateOrderHash(
            _amount,
            _tokenId,
            _tokenAddress,
            tokenCurrency,
            0
        );
        require(
            verifySignature(messageHash, _signature, maker),
            "Bid Function: Invalid signature"
        );

        executeERC20Transfer(tokenCurrency, maker, address(this), _amount);

        Bid storage bid = _bid[bidId];
        bid.bidId = bidId;
        bid.bidder = maker;
        bid.amount = _amount;
        bid.tokenId = _tokenId;
        bid.tokenAddress = _tokenAddress;
        bid.tokenCurrency = tokenCurrency;
        bid.nonce = nonce;
        bid.status = 0;
        bid.taker = address(0);
        bid.nonceKey = nonceKey;

        emit MakeABid(maker, _tokenId, _tokenAddress, _amount, bidId);
    }

    /* Working */
    function cancellBid(
        bytes32 _bidId,
        uint256 _tokenId,
        uint256 _nonce
    ) external nonReentrant {
        Bid storage bid = _bid[_bidId];
        address maker = msg.sender;

        require(
            getNonce(bid.nonceKey) == _nonce &&
                bid.nonceKey == getNonceKey(_nonce),
            "Bid Function: Nonce does not match"
        );

        require(
            bid.status == 0,
            "Bid Function: Bid has been accepted or has already been cancelled"
        );

        require(
            maker == bid.bidder,
            "Bid Function: Only the bidder can cancell the Bid"
        );
        require(
            _tokenId == bid.tokenId,
            "Bid Function: Bid ID does not match with Token ID"
        );

        if (bid.tokenCurrency != address(0)) {
            executeERC20TransferBack(bid.tokenCurrency, bid.bidder, bid.amount);
        } else {
            safeSendETH(bid.bidder, bid.amount);
        }

        bid.status = 2;

        emit CancellBid(maker, _tokenId, bid.tokenAddress, _bidId);
    }

    /* Working */
    function updateBid(
        uint256 _nonce,
        bytes32 _bidId,
        uint256 _newPrice
    ) external payable noZero(_newPrice) nonReentrant {
        Bid storage bid = _bid[_bidId];

        require(
            bid.tokenCurrency == address(0),
            "Bid Functions: Only you can update bid made with ether"
        );

        require(
            msg.sender == bid.bidder,
            "Bid Function: You can't update this auction"
        );

        require(
            getNonce(bid.nonceKey) == _nonce &&
                bid.nonceKey == getNonceKey(_nonce),
            "Bid Function: Nonce does not match"
        );

        require(
            _newPrice != bid.amount,
            "Bid Functions: bid must be different to previous amount"
        );

        require(bid.status == 0, "Bid Function: Bid accepted or cancelled");

        uint256 previousAmount = bid.amount;

        if (previousAmount != 0) {
            // Returning back amount paid by user for old price
            safeSendETH(bid.bidder, previousAmount);
        }

        if (_newPrice != previousAmount) {
            bid.amount = _newPrice;
        }

        emit UpdateBid(bid.tokenAddress, bid.tokenId, _newPrice, _bidId);
    }

    function _takeABid(
        address _tokenAddress,
        uint256 _tokenId,
        bytes32 _bidId,
        bytes memory _signature,
        uint256 _nonce
    ) external nonReentrant {
        Bid storage bid = _bid[_bidId];
        address taker = msg.sender;
        IERC721 tokenAddress = IERC721(bid.tokenAddress);
        bid.taker = taker;

        require(
            bid.status == 0,
            "Bid Functions: this bid has been accepted or cancelled"
        );

        require(
            getNonce(bid.nonceKey) == _nonce &&
                bid.nonceKey == getNonceKey(_nonce),
            "Bid Function: Nonce does not match"
        );

        require(
            taker == tokenAddress.ownerOf(bid.tokenId),
            "Bid Functions: Only the owner can take the bid"
        );

        require(
            address(this) == tokenAddress.getApproved(bid.tokenId),
            "Bid Functions: You must approve to the caller"
        );

        bytes32 messageHash = generateOrderHash(
            bid.amount,
            bid.tokenId,
            bid.tokenAddress,
            bid.tokenCurrency,
            0
        );
        require(
            verifySignature(messageHash, _signature, taker),
            "Bid Function: Invalid signature"
        );

        require(
            _tokenAddress == bid.tokenAddress && _tokenId == bid.tokenId,
            "Bid Functions: bid data does not match with bid ID"
        );

        uint256 feeAmount = (bid.amount * feeRate) / 100;

        executeERC721Transfer(bid.tokenAddress, taker, bid.bidder, bid.tokenId);

        if (bid.tokenCurrency != address(0)) {
            executeERC20TransferBack(
                bid.tokenCurrency,
                bid.taker,
                bid.amount - feeAmount
            );

            executeERC20TransferBack(
                bid.tokenCurrency,
                feeRecipient,
                feeAmount
            );
        } else {
            safeSendETH(taker, bid.amount - feeAmount);
            if (feeRecipient != address(0)) {
                safeSendETH(feeRecipient, feeAmount);
            }
        }

        bid.status = 1;
        delete isTokenSale[_tokenAddress][_tokenId];

        emit TakeBid(bid.tokenAddress, bid.tokenId, bid.bidder, taker, _bidId);
    }
}
