// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DepositManager
 * @dev Library for managing ETH deposits in RFQ settlements
 *
 * This library consolidates deposit management logic for native ETH deposits
 * associated with RFQ settlements. It handles deposit creation, withdrawal,
 * and validation.
 *
 * Key Features:
 * - Deposit creation with amount validation
 * - Safe withdrawal with balance checks
 * - Integration with ethDeposits mapping for state management
 *
 * Note: All custom errors are defined in the main RFQSettlement contract.
 * This library uses low-level reverts to trigger those errors in the main contract.
 */
library DepositManager {
    /**
     * @dev Create a new deposit for an RFQ
     *
     * Validates that msg.value is non-zero and stores the deposit amount
     * in the ethDeposits mapping. Returns the amount for event emission.
     *
     * @param rfqId Unique identifier for the RFQ
     * @param ethDeposits Storage mapping for tracking ETH deposits
     * @return amount The amount deposited
     */
    function createDeposit(bytes32 rfqId, mapping(bytes32 => uint256) storage ethDeposits)
        internal
        returns (uint256 amount)
    {
        if (msg.value == 0) {
            // Revert with InvalidDepositAmount() selector: 0xfe9ba5cd
            assembly {
                mstore(0x00, 0xfe9ba5cd00000000000000000000000000000000000000000000000000000000)
                revert(0x00, 0x04)
            }
        }

        ethDeposits[rfqId] = msg.value;
        return msg.value;
    }

    /**
     * @dev Withdraw a deposit from an RFQ
     *
     * Validates that a deposit exists, clears it from storage, and transfers
     * the ETH to msg.sender. Returns the amount for event emission.
     *
     * @param rfqId Unique identifier for the RFQ
     * @param ethDeposits Storage mapping for tracking ETH deposits
     * @return amount The amount withdrawn
     */
    function withdrawDeposit(bytes32 rfqId, mapping(bytes32 => uint256) storage ethDeposits)
        internal
        returns (uint256 amount)
    {
        amount = ethDeposits[rfqId];
        if (amount == 0) {
            // Revert with NoDepositFound() selector: 0xd1dafa85
            assembly {
                mstore(0x00, 0xd1dafa8500000000000000000000000000000000000000000000000000000000)
                revert(0x00, 0x04)
            }
        }

        // Clear deposit before transfer (reentrancy protection)
        ethDeposits[rfqId] = 0;

        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) {
            // Revert with WithdrawalFailed() selector: 0x27fcd9d1
            assembly {
                mstore(0x00, 0x27fcd9d100000000000000000000000000000000000000000000000000000000)
                revert(0x00, 0x04)
            }
        }
    }
}
