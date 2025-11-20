// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TokenTransfer
 * @dev Library for unified token transfer patterns (ERC20 + native ETH)
 *
 * This library consolidates all token transfer logic to eliminate duplication
 * and provide consistent handling of both ERC20 tokens and native ETH transfers.
 *
 * Key Features:
 * - Unified transferToken() interface for ERC20 and ETH
 * - Deposit locking for cross-chain RFQs
 * - Safe ETH transfer handling with error checking
 * - Integration with ethDeposits mapping for native ETH tracking
 *
 * Note: All custom errors are defined in the main RFQSettlement contract.
 * This library uses low-level reverts to trigger those errors in the main contract.
 */
library TokenTransfer {
    using SafeERC20 for IERC20;

    /**
     * @dev ETH sentinel address used throughout EVM chains
     * This constant is duplicated from main contract for library independence
     */
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /**
     * @dev Transfer tokens (ERC20 or native ETH) from one address to another
     *
     * This function unifies the transfer pattern for both token types. For ETH,
     * it uses a low-level call. For ERC20, it uses SafeERC20.
     *
     * @param token Address of the token (or ETH sentinel)
     * @param from Address to transfer from (unused for ETH, uses msg.value)
     * @param to Address to transfer to
     * @param amount Amount to transfer
     */
    function transferToken(address token, address from, address to, uint256 amount) internal {
        if (token == ETH) {
            // For ETH, amount should already be in msg.value
            (bool success,) = to.call{value: amount}("");
            if (!success) {
                // Revert with ETHTransferFailed() selector: 0xb12d13eb
                assembly {
                    mstore(0x00, 0xb12d13eb00000000000000000000000000000000000000000000000000000000)
                    revert(0x00, 0x04)
                }
            }
        } else {
            // For ERC20, use SafeERC20
            IERC20(token).safeTransferFrom(from, to, amount);
        }
    }

    /**
     * @dev Send native ETH to a recipient with proper error handling
     *
     * @param recipient Address to receive ETH
     * @param amount Amount of ETH to send
     */
    function sendETH(address recipient, uint256 amount) internal {
        (bool success,) = recipient.call{value: amount}("");
        if (!success) {
            // Revert with ETHTransferFailed() selector: 0xb12d13eb
            assembly {
                mstore(0x00, 0xb12d13eb00000000000000000000000000000000000000000000000000000000)
                revert(0x00, 0x04)
            }
        }
    }

    /**
     * @dev Lock tokens for a cross-chain deposit
     *
     * For ETH: Validates msg.value and records in ethDeposits mapping
     * For ERC20: Transfers tokens from sender to this contract
     *
     * @param token Address of the token to lock (or ETH sentinel)
     * @param from Address tokens are being locked from
     * @param amount Amount to lock
     * @param rfqId Unique identifier for the RFQ (for ETH deposit tracking)
     * @param ethDeposits Storage mapping for tracking ETH deposits
     */
    function lockTokens(
        address token,
        address from,
        uint256 amount,
        bytes32 rfqId,
        mapping(bytes32 => uint256) storage ethDeposits
    ) internal {
        if (token == ETH) {
            // For native ETH, we need msg.value to cover the amount
            if (msg.value < amount) {
                // Revert with InvalidDepositAmount() selector: 0xfe9ba5cd
                assembly {
                    mstore(0x00, 0xfe9ba5cd00000000000000000000000000000000000000000000000000000000)
                    revert(0x00, 0x04)
                }
            }
            ethDeposits[rfqId] = amount;
        } else {
            // Transfer ERC20 tokens from sender to this contract
            IERC20(token).safeTransferFrom(from, address(this), amount);
        }
    }

    /**
     * @dev Unlock and transfer ETH from a deposit to a recipient
     *
     * Validates sufficient balance exists in the deposit, updates the mapping,
     * and sends ETH to the recipient.
     *
     * @param rfqId Unique identifier for the RFQ
     * @param recipient Address to receive the ETH
     * @param amount Amount of ETH to unlock
     * @param ethDeposits Storage mapping for tracking ETH deposits
     */
    function unlockETH(
        bytes32 rfqId,
        address recipient,
        uint256 amount,
        mapping(bytes32 => uint256) storage ethDeposits
    ) internal {
        if (ethDeposits[rfqId] < amount) {
            // Revert with InsufficientETHDeposit() selector: 0xb38bd71f
            assembly {
                mstore(0x00, 0xb38bd71f00000000000000000000000000000000000000000000000000000000)
                revert(0x00, 0x04)
            }
        }

        ethDeposits[rfqId] -= amount;
        sendETH(recipient, amount);
    }
}
