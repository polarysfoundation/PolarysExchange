// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract TransferHelper is ERC721Holder {

    function executeERC721Transfer(
        address _tokenAddress,
        address _from,
        address _to,
        uint256 _tokenId
    ) internal {
        IERC721(_tokenAddress).safeTransferFrom(_from, _to, _tokenId);
    }

    function executeERC20Transfer(
        address _tokenAddress,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        IERC20(_tokenAddress).transferFrom(_from, _to, _amount);
    }

    function executeERC20TransferBack(
        address _tokenAddress,
        address _to,
        uint256 _amount
    ) internal {
        IERC20(_tokenAddress).transfer(_to, _amount);
    }

    function executeERC1155Transfer(
        address _tokenAddress,
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _amount,
        bytes calldata _data
    ) internal {
        IERC1155(_tokenAddress).safeTransferFrom(
            _from,
            _to,
            _tokenId,
            _amount,
            _data
        );
    }

    function safeSendETH(address recipient, uint256 amount) internal {
        require(
            address(this).balance >= amount,
            "Insufficient contract balance"
        );

        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "Failed to send ETH");
    }
}
