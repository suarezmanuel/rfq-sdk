// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MaliciousReceiver
 * @dev Contract that rejects ETH transfers for testing transfer failure scenarios
 */
contract MaliciousReceiver {
    // Reject all ETH transfers by reverting in receive function
    receive() external payable {
        revert("ETH transfer rejected");
    }
}
