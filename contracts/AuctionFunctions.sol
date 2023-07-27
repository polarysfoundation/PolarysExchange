// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./Structs.sol";
import "./Variables.sol";
import "./OrderUtils.sol";
import "./TransferHelper.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract AuctionFunctions is
    Structs,
    Variables,
    OrderUtils,
    TransferHelper,
    ReentrancyGuard
{
    using SafeMath for uint256;

    event CreateAuction(
        address seller,
        address tokenAddress,
        address tokenCurrency,
        uint256 reservedPrice,
        uint256 tokenId,
        bytes32 auctionId,
        bytes32 nonceKey
    );

    event PlaceBid(
        address tokenAddress,
        address tokenCurrency,
        uint256 highestBid,
        uint256 tokenId,
        bytes32 auctionId,
        address highestBidder
    );

    event ClaimAuction(
        address tokenAddress,
        address highestBidder,
        uint256 tokenId,
        bytes32 auctionId,
        uint256 highestBid
    );

    event CancellAuction(
        address tokenAddress,
        uint256 tokenId,
        bytes32 auctionId
    );

    event UpdateAuction(
        address tokenAddress,
        uint256 tokenId,
        uint256 newPrice
    );

    function createAuction(
        address _tokenAddress,
        address _tokenCurrency,
        uint256 _tokenId,
        uint256 _reservedPrice,
        bytes memory _signature
    ) external noZero(_reservedPrice) nonReentrant {
        bytes32 auctionId = generateId(_tokenId, _tokenAddress);
        bytes32 nonceKey = generateNonce(auctionId);
        uint256 nonce = getNonce(nonceKey);

        IERC721 tokenAddress = IERC721(_tokenAddress);
        address tokenOwner = tokenAddress.ownerOf(_tokenId);
        bool isApproved = tokenAddress.isApprovedForAll(
            msg.sender,
            address(this)
        );

        require(
            address(this) == tokenAddress.getApproved(_tokenId) || isApproved,
            "Auction Functions: Please approve to the caller"
        );

        require(
            !isTokenSale[_tokenAddress][_tokenId].activeSaleExists,
            "Auction Functions: Token already put on sale"
        );

        require(tokenOwner == msg.sender, "Only owner can create an auction");

        // Verify the signature
        bytes32 messageHash = generateOrderHash(
            _reservedPrice,
            _tokenId,
            _tokenAddress,
            _tokenCurrency,
            0
        );
        require(
            verifySignature(messageHash, _signature, msg.sender),
            "Invalid signature"
        );

        Auction storage auction = _auction[auctionId];
        auction.seller = msg.sender;
        auction.highestBidder = address(0);
        auction.tokenAddress = _tokenAddress;
        auction.tokenCurrency = _tokenCurrency;
        auction.tokenId = _tokenId;
        auction.endTime = 0;
        auction.reservedPrice = _reservedPrice;
        auction.auctionId = auctionId;
        auction.status = 0;
        auction.highestBid = 0;
        auction.nonce = nonce;
        auction.nonceKey = nonceKey;
        isTokenSale[_tokenAddress][_tokenId] = ActiveSales(true);

        emit CreateAuction(
            msg.sender,
            _tokenAddress,
            _tokenCurrency,
            _reservedPrice,
            _tokenId,
            auctionId,
            nonceKey
        );
    }

    function _placeBid(
        bytes32 _auctionId,
        address _tokenAddress,
        uint256 _tokenId,
        bytes memory _signature,
        uint256 _nonce,
        uint256 _amount
    ) external payable noZero(_amount) nonReentrant {
        Auction storage auction = _auction[_auctionId];

        require(
            msg.value == _amount,
            "Auction Functions: Insufient amount to transfer"
        );

        require(
            auction.tokenCurrency == address(0),
            "Auction Functions: Invalid transaction"
        );

        require(
            getNonce(auction.nonceKey) == _nonce &&
                auction.nonceKey == getNonceKey(_nonce),
            "Auction Functions: Nonce does not match"
        );

        require(
            auction.tokenId == _tokenId,
            "Auction Functions: Auction ID does not match with Token ID"
        );
        require(
            auction.status == 0 || auction.status == 3,
            "Auction Functions: Auction has ended or has been cancelled"
        );
        require(
            auction.seller == IERC721(_tokenAddress).ownerOf(_tokenId),
            "Auction Functions: This token has already been sold"
        );

        bytes32 messageHash = generateOrderHash(
            _amount,
            _tokenId,
            _tokenAddress,
            auction.tokenCurrency,
            auction.endTime
        );
        require(
            verifySignature(messageHash, _signature, msg.sender),
            "Auction Functions: Invalid signature"
        );

        require(
            msg.sender != auction.seller,
            "Auction Functions: You can't place a bid in this Auction"
        );

        if (auction.status == 3 && auction.highestBidder != address(0)) {
            uint256 requiredBid = (auction.highestBid * 2) / 100;

            require(
                auction.endTime > block.timestamp,
                "Auction Functions: This auction has ended"
            );
            require(
                _amount > requiredBid,
                "Auction Functions: Bid must be 2% higher than the current bid"
            );

            address previousBidder = auction.highestBidder;
            uint256 previousBid = auction.highestBid;

            auction.highestBidder = msg.sender;
            auction.highestBid = msg.value;

            if (previousBidder != address(0)) {
                safeSendETH(previousBidder, previousBid);
            }

            if (auction.endTime - block.timestamp <= 1200) {
                auction.endTime += 120; // Add 2 minutes (120 seconds) to the endTime
            }
        }

        require(
            _amount >= auction.reservedPrice,
            "Auction Functions: The bid must be same or higher than the reserved price"
        );

        auction.status = 3;
        auction.highestBidder = msg.sender;
        auction.highestBid = _amount;
        auction.endTime = calculateAuctionEndTime();
        //auction.endTime = block.timestamp + 360;

        emit PlaceBid(
            _tokenAddress,
            auction.tokenCurrency,
            _amount,
            _tokenId,
            _auctionId,
            msg.sender
        );
    }

    function placeBid(
        bytes32 _auctionId,
        address _tokenAddress,
        address _tokenCurrency,
        uint256 _tokenId,
        bytes memory _signature,
        uint256 _nonce,
        uint256 _amount
    ) external noZero(_amount) nonReentrant {
        Auction storage auction = _auction[_auctionId];

        require(
            auction.tokenCurrency != address(0) && _tokenCurrency != address(0),
            "Auction Functions: Invalid Transaction"
        );

        require(
            getNonce(auction.nonceKey) == _nonce &&
                auction.nonceKey == getNonceKey(_nonce),
            "Auction Functions: Nonce does not match"
        );

        require(
            auction.tokenId == _tokenId,
            "Auction Functions: Auction ID does not match with Token ID"
        );
        require(
            auction.status == 0 || auction.status == 3,
            "Auction Functions: Auction has ended or has been cancelled"
        );
        require(
            auction.seller == IERC721(_tokenAddress).ownerOf(_tokenId),
            "Auction Functions: This token has already been sold"
        );

        bytes32 messageHash = generateOrderHash(
            _amount,
            _tokenId,
            _tokenAddress,
            auction.tokenCurrency,
            auction.endTime
        );
        require(
            verifySignature(messageHash, _signature, msg.sender),
            "Auction Functions: Invalid signature"
        );

        require(
            msg.sender != auction.seller,
            "Auction Functions: You can't place a bid in this Auction"
        );

        if (auction.status == 3) {
            uint256 requiredBid = (auction.highestBid * 2) / 100;

            require(
                auction.endTime > block.timestamp,
                "Auction Functions: This auction has ended"
            );
            require(
                _amount > requiredBid,
                "Auction Functions: Bid must be 2% higher than the current bid"
            );

            address previousBidder = auction.highestBidder;
            uint256 previousBid = auction.highestBid;

            auction.highestBidder = msg.sender;
            auction.highestBid = _amount;

            executeERC20Transfer(
                auction.tokenCurrency,
                msg.sender,
                address(this),
                _amount
            );

            if (previousBidder != address(0)) {
                executeERC20TransferBack(
                    auction.tokenCurrency,
                    previousBidder,
                    previousBid
                );
            }

            if (auction.endTime - block.timestamp <= 1200) {
                auction.endTime += 120; // Add 2 minutes (120 seconds) to the endTime
            }
        }

        require(
            _amount >= auction.reservedPrice,
            "Auction Functions: The bid must be same or higher than the reserved price"
        );

        executeERC20Transfer(
            auction.tokenCurrency,
            msg.sender,
            address(this),
            _amount
        );

        auction.status = 3;
        auction.highestBidder = msg.sender;
        auction.highestBid = _amount;
        auction.endTime = calculateAuctionEndTime();
        //auction.endTime = block.timestamp + 360;

        emit PlaceBid(
            _tokenAddress,
            auction.tokenCurrency,
            _amount,
            _tokenId,
            _auctionId,
            msg.sender
        );
    }

    function _claimAuction(
        address _tokenAddress,
        bytes32 _auctionId,
        uint256 _nonce,
        uint256 _tokenId,
        bytes memory _signature
    ) external nonReentrant {
        Auction storage auction = _auction[_auctionId];
        address operator = msg.sender;

        require(
            getNonce(auction.nonceKey) == _nonce &&
                auction.nonceKey == getNonceKey(_nonce),
            "Auction Functions: Nonce does not match"
        );

        require(
            operator == auction.seller || operator == auction.highestBidder,
            "Auction Functions: You are not able to claim this auction reward"
        );

        require(
            auction.endTime < block.timestamp,
            "Auction Functions: auction has not ended"
        );

        require(
            auction.status == 3,
            "Auction Functions: auction has not started"
        );

        require(
            auction.tokenId == _tokenId &&
                auction.tokenAddress == _tokenAddress,
            "Auction Functions: Data auction does not match with auction ID"
        );

        if (operator == auction.seller) {
            bytes32 messageHash = generateOrderHash(
                auction.reservedPrice,
                auction.tokenId,
                auction.tokenAddress,
                auction.tokenCurrency,
                auction.endTime
            );
            require(
                verifySignature(messageHash, _signature, operator),
                "Auction Functions: Invalid signature"
            );
        } else if (operator == auction.highestBidder) {
            bytes32 messageHash = generateOrderHash(
                auction.highestBid,
                auction.tokenId,
                auction.tokenAddress,
                auction.tokenCurrency,
                auction.endTime
            );

            require(
                verifySignature(messageHash, _signature, operator),
                "Auction Functions: Invalid signature"
            );
        }

        uint256 feeAmount = (auction.highestBid * feeRate) / 100;

        executeERC721Transfer(
            auction.tokenAddress,
            auction.seller,
            auction.highestBidder,
            auction.tokenId
        );

        if (auction.tokenCurrency != address(0)) {
            executeERC20TransferBack(
                auction.tokenCurrency,
                auction.seller,
                auction.highestBid - feeAmount
            );

            executeERC20TransferBack(
                auction.tokenCurrency,
                feeRecipient,
                feeAmount
            );
        } else {
            safeSendETH(auction.seller, auction.highestBid - feeAmount);
            safeSendETH(feeRecipient, feeAmount);
        }

        auction.status = 4;
        delete isTokenSale[_tokenAddress][_tokenId];

        emit ClaimAuction(
            auction.tokenAddress,
            auction.highestBidder,
            auction.tokenId,
            _auctionId,
            auction.highestBid
        );
    }

    function cancelAuction(
        address _tokenAddress,
        uint256 _tokenId,
        bytes32 _auctionId,
        uint256 _nonce
    ) external nonReentrant {
        Auction storage auction = _auction[_auctionId];
        address tokenOwner = IERC721(_tokenAddress).ownerOf(_tokenId);

        require(
            getNonce(auction.nonceKey) == _nonce &&
                auction.nonceKey == getNonceKey(_nonce),
            "Nonce does not match"
        );

        require(
            tokenOwner == msg.sender ||
                IERC721(_tokenAddress).getApproved(_tokenId) == msg.sender,
            "Only owner or operator can cancell this auction"
        );

        require(
            auction.status == 0,
            "Auction has been cacelled or has started"
        );

        auction.status = 2;
        delete isTokenSale[_tokenAddress][_tokenId];

        emit CancellAuction(_tokenAddress, _tokenId, _auctionId);
    }

    function updateAuction(
        uint256 _nonce,
        bytes32 _auctionId,
        uint256 _newPrice
    ) external nonReentrant {
        Auction storage auction = _auction[_auctionId];

        require(
            msg.sender == auction.seller,
            "Auction Functions: You can't update this auction"
        );

        require(
            auction.status == 0,
            "Auction Functions: this auctiuon can't be updated"
        );

        require(
            getNonce(auction.nonceKey) == _nonce &&
                auction.nonceKey == getNonceKey(_nonce),
            "Nonce does not match"
        );

        auction.reservedPrice = _newPrice;

        emit UpdateAuction(auction.tokenAddress, auction.tokenId, _newPrice);
    }
}
