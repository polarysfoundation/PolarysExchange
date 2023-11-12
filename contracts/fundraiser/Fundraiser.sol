// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract FundRaiser is ReentrancyGuard {
    address public owner = msg.sender;

    function withdraw(address erc20) public nonReentrant {
        require(msg.sender == owner, "Only the contract owner can withdraw");
        
    }

    function safeSendETH(address recipient, uint256 amount) private {
        require(
            address(this).balance >= amount,
            "Polarys Exchange: Insufficient contract balance"
        );

        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "Polarys Exchange: Failed to send ETH");
    }

    
    function executeERC20TransferBack(
        address _tokenAddress,
        address _to,
        uint256 _amount
    ) internal {
        IERC20(_tokenAddress).transfer(_to, _amount);
    }
}
