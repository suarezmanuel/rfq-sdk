// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

/**
 * @title RFQSettlement
 * @dev Settlement contract for atomic P2P trades on same chain
 *
 * This contract handles RFQ (Request for Quote) settlements using atomic swaps.
 * It validates RFQ terms, transfers baseToken from creator to acceptor, and transfers
 * quoteToken from acceptor to creator in a single transaction.
 */
contract RFQSettlement {
    using SafeERC20 for IERC20;

    uint256 public constant VERSION = 1;

    /**
     * @dev Emitted when a trade is executed successfully
     * @param rfqId Unique identifier for the RFQ
     * @param creator Address of the RFQ creator
     * @param acceptor Address of the RFQ acceptor
     * @param baseToken Address of the base token being swapped
     * @param quoteToken Address of the quote token being swapped
     * @param baseAmount Amount of base token transferred
     * @param quoteAmount Amount of quote token transferred
     */
    event TradeExecuted(
        bytes32 indexed rfqId,
        address indexed creator,
        address indexed acceptor,
        address baseToken,
        address quoteToken,
        uint256 baseAmount,
        uint256 quoteAmount
    );

    /**
     * @dev Execute an atomic swap for a same-chain RFQ
     *
     * Requirements:
     * - baseToken and quoteToken addresses must be non-zero
     * - baseAmount and quoteAmount must be greater than zero
     * - creator must have approved this contract to spend baseAmount of baseToken
     * - acceptor must have approved this contract to spend quoteAmount of quoteToken
     * - creator must have sufficient balance of baseToken
     * - acceptor must have sufficient balance of quoteToken
     *
     * @param rfqId Unique identifier for the RFQ being settled
     * @param creator Address of the RFQ creator (selling base token)
     * @param baseToken Address of the base token contract
     * @param quoteToken Address of the quote token contract
     * @param baseAmount Amount of base token to transfer from creator to acceptor
     * @param quoteAmount Amount of quote token to transfer from acceptor to creator
     */
    function execute(
        bytes32 rfqId,
        address creator,
        address baseToken,
        address quoteToken,
        uint256 baseAmount,
        uint256 quoteAmount
    ) external {
        require(baseToken != address(0) && quoteToken != address(0), "Invalid token address");
        require(baseAmount > 0 && quoteAmount > 0, "Invalid amount");
        require(creator != address(0), "Invalid creator address");

        address acceptor = msg.sender;

        // Swap
        IERC20(baseToken).safeTransferFrom(creator, acceptor, baseAmount);
        IERC20(quoteToken).safeTransferFrom(acceptor, creator, quoteAmount);

        emit TradeExecuted(rfqId, creator, acceptor, baseToken, quoteToken, baseAmount, quoteAmount);
    }

    /**
     * @dev Future: Async execution of RFQ settlement
     */
    function executeAsync() external pure {
        revert("Not implemented");
    }

    /**
     * @dev Future: Partial fill of RFQ settlement
     */
    function executePartialFill() external pure {
        revert("Not implemented");
    }
}
