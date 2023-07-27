// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Structs.sol";
import "./Variables.sol";
import "./OrderUtils.sol";
import "./TransferHelper.sol";

contract OrderFunctions is
    Structs,
    Variables,
    OrderUtils,
    TransferHelper,
    ReentrancyGuard
{
    using SafeMath for uint256;

    event CreateOrder(
        address seller,
        address buyer,
        address tokenAddress,
        uint256 price,
        uint256 tokenId,
        address tokenCurrency,
        uint256 orderEndTime,
        bytes32 orderId,
        bytes32 nonceKey
    );

    event FullFillOrder(
        bytes32 orderId,
        address seller,
        address buyer,
        address tokenAddress,
        uint256 tokenId,
        uint256 price,
        address tokenCurrency
    );

    event CancellOrder(
        bytes32 orderId,
        uint256 tokenId,
        address tokenAddress,
        address tokenCurrency
    );

    event UpdateOrder(address tokenAddress, uint256 tokenId, uint256 newPrice);

    function createOrder(
        uint256 _price,
        uint256 _tokenId,
        address _tokenAddress,
        address _tokenCurrency,
        uint256 _endTime,
        bytes memory _signature
    ) public nonReentrant noZero(_price) {
        bytes32 orderId = generateId(_tokenId, _tokenAddress);
        uint256 orderEndTime = calculateEndTime(_endTime);

        bytes32 _nonceKey = generateNonce(orderId);
        uint256 nonce = getNonce(_nonceKey);

        IERC721 tokenAddress = IERC721(_tokenAddress);

        bool isApproved = tokenAddress.isApprovedForAll(
            msg.sender,
            address(this)
        );

        require(
            _endTime <= 3,
            "Order Functions: End time can't be higher than 3"
        );

        require(
            !isTokenSale[_tokenAddress][_tokenId].activeSaleExists,
            "Auction Functions: Token already put on sale"
        );

        require(
            tokenAddress.ownerOf(_tokenId) == msg.sender ||
                tokenAddress.getApproved(_tokenId) == address(this) ||
                isApproved,
            "Order Functions: Only owner or operator can create an Order"
        );

        bytes32 messageHash = generateOrderHash(
            _price,
            _tokenId,
            _tokenAddress,
            _tokenCurrency,
            _endTime
        );

        require(
            verifySignature(messageHash, _signature, msg.sender),
            "Order Functions: Invalid signature"
        );

        Order storage order = _order[orderId];
        order.seller = msg.sender;
        order.buyer = address(0);
        order.tokenAddress = _tokenAddress;
        order.price = _price;
        order.tokenId = _tokenId;
        order.tokenCurrency = _tokenCurrency;
        order.orderId = orderId;
        order.orderEndTime = orderEndTime;
        order.status = 0;
        order.nonce = nonce;
        order.nonceKey = _nonceKey;
        isTokenSale[_tokenAddress][_tokenId] = ActiveSales(true);

        emit CreateOrder(
            msg.sender,
            address(0),
            _tokenAddress,
            _price,
            _tokenId,
            _tokenCurrency,
            orderEndTime,
            orderId,
            _nonceKey
        );
    }

    function _fullFillOrder(
        address _tokenAddress,
        bytes32 _orderId,
        uint256 _tokenId,
        uint256 _price,
        bytes memory _signature,
        uint256 _nonce
    ) public payable nonReentrant noZero(_price) {
        Order storage order = _order[_orderId];

        IERC721 tokenAddress = IERC721(_tokenAddress);

        require(
            order.tokenCurrency == address(0),
            "Order Functions: Invalid Transaction"
        );

        require(
            getNonce(order.nonceKey) == _nonce &&
                order.nonceKey == getNonceKey(_nonce),
            "Order Functions: Nonce does not match"
        );

        require(
            tokenAddress.ownerOf(_tokenId) == order.seller && order.status == 0,
            "Order Functions: Token has been sold or cancelled"
        );

        require(
            order.orderEndTime > block.timestamp,
            "Order Functions: Order has been cancelled"
        );
        require(
            order.tokenId == _tokenId,
            "Order Functions: Order ID does not match with token ID"
        );
        require(
            order.price == _price,
            "Order Functions: Price does not match the order price"
        );

        bytes32 messageHash = generateOrderHash(
            _price,
            _tokenId,
            _tokenAddress,
            address(0),
            order.orderEndTime
        );

        require(
            verifySignature(messageHash, _signature, msg.sender),
            "Order Functions: Invalid signature"
        );

        executeERC721Transfer(
            _tokenAddress,
            order.seller,
            msg.sender,
            _tokenId
        );

        uint256 feeAmount = (_price * feeRate) / 100;

        require(
            _price == msg.value,
            "TransferHelper: Incorrect payment amount"
        );

        payable(order.seller).transfer(_price - feeAmount);
        payable(feeRecipient).transfer(feeAmount);

        order.buyer = msg.sender;
        order.status = 1;
        delete isTokenSale[_tokenAddress][_tokenId];

        emit FullFillOrder(
            _orderId,
            order.seller,
            msg.sender,
            _tokenAddress,
            _tokenId,
            _price,
            address(0)
        );
    }

    function fullFillOrder(
        address _tokenAddress,
        address _tokenCurrency,
        bytes32 _orderId,
        uint256 _tokenId,
        uint256 _price,
        bytes memory _signature,
        uint256 _nonce
    ) public nonReentrant {
        Order storage order = _order[_orderId];

        IERC721 tokenAddress = IERC721(_tokenAddress);

        require(
            order.tokenCurrency != address(0) && _tokenCurrency != address(0),
            "Order Functions: Invalid Transaction"
        );

        require(
            getNonce(order.nonceKey) == _nonce &&
                order.nonceKey == getNonceKey(_nonce),
            "Order Functions: Nonce does not match"
        );

        require(
            tokenAddress.ownerOf(_tokenId) == order.seller && order.status == 0,
            "Order Functions: Token has been sold or cancelled"
        );

        require(
            order.orderEndTime > block.timestamp,
            "Order Functions: Order has been cancelled"
        );
        require(
            order.tokenId == _tokenId,
            "Order Functions: Order ID does not match with token ID"
        );
        require(
            order.price == _price,
            "Order Functions: Price does not match the order price"
        );

        bytes32 messageHash = generateOrderHash(
            _price,
            _tokenId,
            _tokenAddress,
            _tokenCurrency,
            order.orderEndTime
        );

        require(
            verifySignature(messageHash, _signature, msg.sender),
            "Order Functions: Invalid signature"
        );

        executeERC721Transfer(
            _tokenAddress,
            order.seller,
            msg.sender,
            _tokenId
        );

        uint256 feeAmount = (_price * feeRate) / 100;

        executeERC20Transfer(
            _tokenCurrency,
            msg.sender,
            order.seller,
            _price - feeAmount
        );

        executeERC20Transfer(
            _tokenCurrency,
            msg.sender,
            feeRecipient,
            feeAmount
        );

        order.buyer = msg.sender;
        order.status = 1;
        delete isTokenSale[_tokenAddress][_tokenId];

        emit FullFillOrder(
            _orderId,
            order.seller,
            msg.sender,
            _tokenAddress,
            _tokenId,
            _price,
            _tokenCurrency
        );
    }

    function cancellOrder(
        address _tokenAddress,
        address _tokenCurrency,
        uint256 _tokenId,
        bytes32 _orderId,
        uint256 _nonce
    ) external nonReentrant {
        Order storage order = _order[_orderId];
        address tokenOwner = IERC721(_tokenAddress).ownerOf(_tokenId);

        require(
            getNonce(order.nonceKey) == _nonce &&
                order.nonceKey == getNonceKey(_nonce),
            "Order Functions: Nonce does not match"
        );

        require(
            order.status == 0,
            "Order Functions: Order full filled or cancelled"
        );

        require(
            order.seller == msg.sender ||
                msg.sender == tokenOwner ||
                order.seller == tokenOwner,
            "Order Functions: Only the owner can cancell this order"
        );

        require(
            order.tokenId == _tokenId,
            "Order Functions: Order ID not match with Token ID"
        );
        require(
            order.tokenAddress == _tokenAddress,
            "Order Functions: Order ID not match with Token Address"
        );

        order.status = 2;
        delete isTokenSale[_tokenAddress][_tokenId];

        emit CancellOrder(_orderId, _tokenId, _tokenAddress, _tokenCurrency);
    }

    function updateOrder(
        uint256 _nonce,
        bytes32 _orderId,
        uint256 _newPrice
    ) external nonReentrant {
        Order storage order = _order[_orderId];

        require(
            getNonce(order.nonceKey) == _nonce &&
                order.nonceKey == getNonceKey(_nonce),
            "Order Functions: Nonce does not match"
        );

        require(
            msg.sender == order.seller,
            "Order Functions: You can't update this order"
        );

        require(
            order.status == 0,
            "Order Functions: Order full filled or cancelled"
        );

        order.price = _newPrice;

        emit UpdateOrder(order.tokenAddress, order.tokenId, _newPrice);
    }
}
