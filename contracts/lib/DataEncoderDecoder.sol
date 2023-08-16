// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Order, Offer} from "./Structs.sol";

library DataEncoderDecoder {
    function decodeOrder(
        bytes memory data
    ) internal pure returns (Order memory) {
        return abi.decode(data, (Order));
    }
}
