// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";

/**
 * @title RFQSettlement
 * @dev Settlement contract for atomic P2P trades on same chain
 *
 * This contract handles RFQ (Request for Quote) settlements using atomic swaps.
 * It validates RFQ terms, transfers baseToken from creator to acceptor, and transfers
 * quoteToken from acceptor to creator in a single transaction.
 */
contract RFQSettlement is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant VERSION = 0;

    /**
     * @dev Sentinel address representing native coins across all EVM chains
     * This address is the EVM standard for native coins (ETH, MATIC, AVAX, etc.)
     * Works identically on Ethereum, Polygon, Avalanche, Base, and all EVM chains
     */
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /**
     * @dev Error thrown when msg.value does not match quoteAmount for native coin trades
     */
    error ETHAmountMismatch();

    /**
     * @dev Error thrown when msg.value is sent but quoteToken is not native coin
     * This prevents accidental loss of native coins
     */
    error UnexpectedETHSent();

    /**
     * @dev Error thrown when native coin transfer to creator fails
     */
    error ETHTransferFailed();

    /**
     * @dev Error thrown when trying to deposit zero native coins
     */
    error InvalidDepositAmount();

    /**
     * @dev Error thrown when trying to withdraw with no deposit
     */
    error NoDepositFound();

    /**
     * @dev Error thrown when native coin transfer to withdrawer fails
     */
    error WithdrawalFailed();

    /**
     * @dev Error thrown when baseToken is native but no deposit exists
     */
    error InsufficientETHDeposit();

    /**
     * @dev Mapping to track native coin deposits for RFQs
     * rfqId => deposited amount in native coins
     */
    mapping(bytes32 => uint256) public ethDeposits;

    /**
     * @dev Emitted when native coins are deposited for an RFQ
     * @param rfqId Unique identifier for the RFQ
     * @param creator Address of the creator depositing native coins
     * @param amount Amount of native coins deposited
     */
    event ETHDeposited(bytes32 indexed rfqId, address indexed creator, uint256 amount);

    /**
     * @dev Emitted when native coins are withdrawn from an RFQ
     * @param rfqId Unique identifier for the RFQ
     * @param creator Address of the creator withdrawing native coins
     * @param amount Amount of native coins withdrawn
     */
    event ETHWithdrawn(bytes32 indexed rfqId, address indexed creator, uint256 amount);

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
     * @dev Deposit native coins for an RFQ where baseToken is native
     *
     * @param rfqId Unique identifier for the RFQ
     */
    function depositForRFQ(bytes32 rfqId) external payable {
        if (msg.value == 0) {
            revert InvalidDepositAmount();
        }

        ethDeposits[rfqId] = msg.value;
        emit ETHDeposited(rfqId, msg.sender, msg.value);
    }

    /**
     * @dev Withdraw native coins from an unused RFQ deposit
     *
     * @param rfqId Unique identifier for the RFQ
     */
    function withdrawDeposit(bytes32 rfqId) external nonReentrant {
        uint256 amount = ethDeposits[rfqId];
        if (amount == 0) {
            revert NoDepositFound();
        }

        // Clear deposit before transfer
        ethDeposits[rfqId] = 0;
        emit ETHWithdrawn(rfqId, msg.sender, amount);

        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) {
            revert WithdrawalFailed();
        }
    }

    /**
     * @dev Execute an atomic swap for a same-chain RFQ
     *
     * @param rfqId Unique identifier for the RFQ being settled
     * @param creator Address of the RFQ creator (selling base token)
     * @param baseToken Address of the base token contract (or ETH sentinel address)
     * @param quoteToken Address of the quote token contract (or ETH sentinel address)
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
    ) external payable nonReentrant {
        require(baseToken != address(0) && quoteToken != address(0), "Invalid token address");
        require(baseAmount > 0 && quoteAmount > 0, "Invalid amount");
        require(creator != address(0), "Invalid creator address");

        // msg.value validations
        if (quoteToken == ETH) {
            if (msg.value != quoteAmount) {
                revert ETHAmountMismatch();
            }
        } else {
            if (msg.value > 0) {
                revert UnexpectedETHSent();
            }
        }

        address acceptor = msg.sender;

        // Conditional logic for baseToken transfer
        if (baseToken == ETH) {
            if (ethDeposits[rfqId] < baseAmount) {
                revert InsufficientETHDeposit();
            }

            // Deduct from deposit
            ethDeposits[rfqId] -= baseAmount;

            (bool success,) = acceptor.call{value: baseAmount}("");
            if (!success) {
                revert ETHTransferFailed();
            }
        } else {
            IERC20(baseToken).safeTransferFrom(creator, acceptor, baseAmount);
        }

        // Conditional payment logic for quoteToken
        if (quoteToken == ETH) {
            (bool success,) = creator.call{value: quoteAmount}("");
            if (!success) {
                revert ETHTransferFailed();
            }
        } else {
            IERC20(quoteToken).safeTransferFrom(acceptor, creator, quoteAmount);
        }

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
