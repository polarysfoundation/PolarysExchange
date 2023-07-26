// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Variables {
    uint8 public feeRate;
    address public feeRecipient;

    modifier noZero(uint256 amount) {
        require(amount != 0, "Amount cannot be zero");
        _;
    }

    function generateId(
        uint256 tokenId,
        address tokenContract
    ) internal view returns (bytes32) {
        bytes32 auctionId = keccak256(
            abi.encodePacked(block.number, tokenId, tokenContract)
        );
        return auctionId;
    }

    function calculateAuctionEndTime() internal view returns (uint256) {
        uint256 currentTime = block.timestamp;
        uint256 endTime = currentTime + 86400; // 86400 seconds in 24 hours
        return endTime;
    }

    function calculateEndTime(
        uint256 durationInMonths
    ) internal view returns (uint256) {
        require(
            durationInMonths >= 1 && durationInMonths <= 3,
            "Invalid duration"
        ); // Validate duration input

        uint256 currentTime = block.timestamp;
        uint256 durationInSeconds = durationInMonths * 30 days; // Assuming 30 days per month
        uint256 endTime = currentTime + durationInSeconds;

        return endTime;
    }
}
