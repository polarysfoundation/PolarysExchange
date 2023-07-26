// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./OrderFunctions.sol";
import "./AuctionFunctions.sol";
import "./BidFunctions.sol";

contract PolarysExchange is
    OrderFunctions,
    AuctionFunctions,
    BidFunctions,
    Ownable
{
    string public constant NAME = "Polarys Exchange";
    string public constant NAME_EXCHANGE = "TAGWEB3";
    string public constant VERSION = "V1.0";
    address public admin;

    constructor(address _setAdmin, address _feeRecipient, uint8 _feeRate) {
        require(
            _setAdmin != address(0),
            "Polarys Exchange: admin can't be the address(0)"
        );
        require(
            _feeRate < 10,
            "Polarys Exchange: Fee rate must be more lower than 10"
        );
        admin = _setAdmin;
        feeRecipient = _feeRecipient;
        feeRate = _feeRate;
    }

    modifier onlyAdmin() {
        require(
            msg.sender == admin,
            "Polarys Exchange: Only admin can call this function"
        );
        _;
    }

    function updateAdmin(address _newAdmin) external onlyOwner {
        admin = _newAdmin;
    }

    function updateFeeRecipient(address _newFeeRecipient) external onlyAdmin {
        feeRecipient = _newFeeRecipient;
    }

    function updateRate(uint8 _feeRate) external onlyAdmin {
        require(_feeRate < 10, "Fee rate must be less than 10");
        feeRate = _feeRate;
    }

    function executeBulkCreateOrders(
        address _tokenAddress,
        uint256[] memory _price,
        uint256[] memory _tokenId,
        address _tokenCurrency,
        uint256 _endTime,
        bytes memory _signature
    ) external {
        require(_tokenAddress != address(0), "Invalid token address");

        require(_tokenId.length == _price.length, "Mismatched arrays");

        for (uint256 i = 0; i < _tokenId.length; i++) {
            createOrder(
                _price[i],
                _tokenId[i],
                _tokenAddress,
                _tokenCurrency,
                _endTime,
                _signature
            );
        }
    }

    function executeBulkFullFillOrder(
        address _tokenAddress,
        address _tokenCurrency,
        bytes32[] memory _orderId,
        uint256[] memory _tokenId,
        uint256[] memory _price,
        bytes memory _signature,
        uint256[] memory _nonce
    ) external {
        require(
            _tokenId.length == _price.length &&
                _tokenId.length == _orderId.length,
            "Mismatched arrays"
        );

        require(_tokenAddress != address(0), "Invalid token address");

        // Check if the array of orderId contains unique values
        for (uint256 i = 0; i < _orderId.length; i++) {
            for (uint256 j = i + 1; j < _orderId.length; j++) {
                require(_orderId[i] != _orderId[j], "Duplicate orderId");
            }
        }

        for (uint256 i = 0; i < _tokenId.length; i++) {
            if (_tokenCurrency != address(0)) {
                fullFillOrder(
                    _tokenAddress,
                    _tokenCurrency,
                    _orderId[i],
                    _tokenId[i],
                    _price[i],
                    _signature,
                    _nonce[i]
                );
            } else {
                _fullFillOrder(
                    _tokenAddress,
                    _orderId[i],
                    _tokenId[i],
                    _price[i],
                    _signature,
                    _nonce[i]
                );
            }
        }
    }
}
