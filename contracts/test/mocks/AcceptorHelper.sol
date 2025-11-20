// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/RFQSettlement.sol";

/**
 * @title AcceptorHelper
 * @dev Helper contract that can execute trades as an EOA-like entity
 */
contract AcceptorHelper {
    function executeTrade(
        address payable settlement,
        bytes32 rfqId,
        address creator,
        address baseToken,
        address quoteToken,
        uint256 baseAmount,
        uint256 quoteAmount
    ) external payable {
        RFQSettlement(settlement).execute{value: msg.value}(
            rfqId, creator, baseToken, quoteToken, baseAmount, quoteAmount
        );
    }

    receive() external payable {}
}
