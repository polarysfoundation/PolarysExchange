// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";

contract OrderUtils {
    using SafeMath for uint256;
    using ECDSA for bytes32;

    uint256 public totalNonces;
    bytes32[] private nonceKeys = [bytes32(0)];

    struct Nonce {
        bytes32 nonceKey;
        uint256 nonce;
    }

    mapping(bytes32 => Nonce) private nonce;

    function generateNonce(bytes32 _orderId) internal returns (bytes32) {
        totalNonces = totalNonces + 1;
        bytes32 nonceKey = keccak256(abi.encodePacked(_orderId, totalNonces));
        Nonce storage nonceData = nonce[nonceKey];
        nonceData.nonce = totalNonces;
        nonceData.nonceKey = _orderId;
        nonceKeys.push(nonceKey);
        return nonceKey;
    }

    function getNonce(bytes32 _nonceKey) public view returns (uint256) {
        return nonce[_nonceKey].nonce;
    }

    function getNonceKey(uint256 _nonce) public view returns (bytes32) {
        require(_nonce != 0, "Invalid nonce");
        return nonceKeys[_nonce];
    }

    function generateOrderHash(
        uint256 _price,
        uint256 _tokenId,
        address _tokenAddress,
        address _tokenCurrency,
        uint256 _endTime
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _price,
                    _tokenId,
                    _tokenAddress,
                    _tokenCurrency,
                    _endTime
                )
            );
    }

    function verifySignature(
        bytes32 _messageHash,
        bytes memory _signature,
        address _signer
    ) internal pure returns (bool) {
        bytes32 ethSignedMessageHash = _messageHash.toEthSignedMessageHash();
        address recoveredSigner = ethSignedMessageHash.recover(_signature);
        return recoveredSigner == _signer;
    }

    function isERC1155(address _tokenAddress) internal view returns (bool) {
        return IERC165(_tokenAddress).supportsInterface(0xd9b67a26); // ERC1155 interface ID
    }
}
