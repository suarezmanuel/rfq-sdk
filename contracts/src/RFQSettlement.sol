// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";
import "@openzeppelin/access/Ownable.sol";

import "./libraries/RFQValidation.sol";
import "./libraries/TokenTransfer.sol";
import "./libraries/DepositManager.sol";
import "./libraries/WormholeCodec.sol";

/**
 * @title RFQSettlement
 * @dev Settlement contract for atomic P2P trades.
 *
 * This contract handles RFQ (Request for Quote) settlements using atomic swaps.
 * It validates RFQ terms, transfers baseToken from creator to acceptor, and transfers
 * quoteToken from acceptor to creator in a single transaction.
 */
contract RFQSettlement is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant VERSION = 0;

    /**
     * @dev Sentinel address representing native coins across all EVM chains
     * This address is the EVM standard for native coins (ETH, MATIC, AVAX, etc.)
     * Works identically on Ethereum, Polygon, Avalanche, Base, and all EVM chains
     */
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /**
     * @dev Struct to track asset deposits for quotes (both ETH and ERC20)
     * For ETH deposits, token address is the ETH sentinel
     */
    struct AssetDeposit {
        address token;
        uint256 amount;
        address depositor;
    }

    /**
     * @dev Unified mapping to track all asset deposits for quotes
     * quoteId => AssetDeposit
     */
    mapping(bytes32 => AssetDeposit) public assetDeposits;

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
     * @dev Error thrown when deposit amount is invalid (used by DepositManager)
     */
    error InvalidDepositAmount();

    /**
     * @dev Error thrown when no deposit found (used by DepositManager)
     */
    error NoDepositFound();

    /**
     * @dev Error thrown when ETH withdrawal fails (used by DepositManager)
     */
    error WithdrawalFailed();

    /**
     * @dev Error thrown when ETH deposit is insufficient (used by TokenTransfer)
     */
    error InsufficientETHDeposit();

    /**
     * @dev Emitted when assets (ETH or ERC20) are deposited for a quote
     * @param quoteId Unique identifier for the quote
     * @param creator Address of the creator depositing assets
     * @param token Address of the token (ETH sentinel for native coins)
     * @param amount Amount of assets deposited
     */
    event AssetDeposited(bytes32 indexed quoteId, address indexed creator, address indexed token, uint256 amount);

    /**
     * @dev Emitted when assets (ETH or ERC20) are withdrawn from a quote
     * @param quoteId Unique identifier for the quote
     * @param creator Address of the creator withdrawing assets
     * @param token Address of the token (ETH sentinel for native coins)
     * @param amount Amount of assets withdrawn
     */
    event AssetWithdrawn(bytes32 indexed quoteId, address indexed creator, address indexed token, uint256 amount);

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
     * @dev Constructor
     */
    constructor() Ownable(msg.sender) {}

    ////////////////////////////////////////////////////////////////////
    // Quote setup
    ////////////////////////////////////////////////////////////////////

    /**
     * @dev Create a quote by depositing tokens (ETH or ERC20)
     *
     * @param quoteId Unique identifier for the quote
     * @param token Address of the token to deposit (use ETH sentinel for native)
     * @param amount Amount of tokens to deposit
     */
    function createQuote(bytes32 quoteId, address token, uint256 amount) external payable nonReentrant {
        require(quoteId != bytes32(0), "Invalid quoteId");
        require(amount > 0, "Amount must be greater than 0");
        require(assetDeposits[quoteId].amount == 0, "Quote already exists");

        if (token == ETH) {
            // ETH deposit
            require(msg.value == amount, "ETH amount mismatch");
            assetDeposits[quoteId] = AssetDeposit({token: ETH, amount: amount, depositor: msg.sender});
        } else {
            // ERC20 deposit
            require(msg.value == 0, "No ETH should be sent for ERC20 deposit");
            require(token != address(0), "Invalid token address");

            // Transfer tokens from sender to contract
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

            // Store deposit info
            assetDeposits[quoteId] = AssetDeposit({token: token, amount: amount, depositor: msg.sender});
        }

        emit AssetDeposited(quoteId, msg.sender, token, amount);
    }

    /**
     * @dev Cancel a quote and withdraw deposited tokens (ETH or ERC20)
     *
     * @param quoteId Unique identifier for the quote
     * @param token Address of the token to withdraw (use ETH sentinel for native)
     */
    function cancelQuote(bytes32 quoteId, address token) external nonReentrant {
        AssetDeposit memory deposit = assetDeposits[quoteId];
        require(deposit.amount > 0, "No deposit found");
        require(deposit.depositor == msg.sender, "Not depositor");
        require(deposit.token == token, "Token mismatch");

        // Clear deposit
        delete assetDeposits[quoteId];

        // Transfer assets back to depositor
        if (token == ETH) {
            (bool success,) = msg.sender.call{value: deposit.amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(token).safeTransfer(msg.sender, deposit.amount);
        }

        emit AssetWithdrawn(quoteId, msg.sender, token, deposit.amount);
    }

    ///////////////////////////////////////////////////////////////////////
    // RFQ execution
    ///////////////////////////////////////////////////////////////////////

    /**
     * @dev Execute an atomic swap for a same-chain RFQ
     *
     * @param quoteId Unique identifier for the Quote
     * @param creator Address of the RFQ creator (selling base token)
     * @param baseToken Address of the base token contract (or ETH sentinel address)
     * @param quoteToken Address of the quote token contract (or ETH sentinel address)
     * @param baseAmount Amount of base token to transfer from creator to acceptor
     * @param quoteAmount Amount of quote token to transfer from acceptor to creator
     */
    function acceptQuote(
        bytes32 quoteId,
        address creator,
        address baseToken,
        address quoteToken,
        uint256 baseAmount,
        uint256 quoteAmount
    ) external payable nonReentrant {
        RFQValidation.validateExecuteParams(baseToken, quoteToken, baseAmount, quoteAmount);
        _validateMsgValue(quoteToken, quoteAmount);

        address acceptor = msg.sender;

        // Validate deposit exists and matches parameters
        AssetDeposit memory deposit = assetDeposits[quoteId];
        require(deposit.amount > 0, "No deposit found");
        require(deposit.depositor == creator, "Creator mismatch");
        require(deposit.token == baseToken, "Base token mismatch");
        require(deposit.amount >= baseAmount, "Insufficient deposit");

        _transferBaseToken(quoteId, creator, acceptor, baseToken, baseAmount);
        _transferQuoteToken(acceptor, creator, quoteToken, quoteAmount);

        emit TradeExecuted(quoteId, creator, acceptor, baseToken, quoteToken, baseAmount, quoteAmount);
    }

    /**
     * @dev Validates msg.value based on quoteToken type
     */
    function _validateMsgValue(address quoteToken, uint256 quoteAmount) private view {
        if (quoteToken == ETH) {
            if (msg.value != quoteAmount) revert ETHAmountMismatch();
        } else {
            if (msg.value > 0) revert UnexpectedETHSent();
        }
    }

    /**
     * @dev Transfers baseToken from creator to acceptor
     */
    function _transferBaseToken(
        bytes32 quoteId,
        address creator,
        address acceptor,
        address baseToken,
        uint256 baseAmount
    ) private {
        AssetDeposit memory deposit = assetDeposits[quoteId];
        require(deposit.amount >= baseAmount, "Insufficient deposit");

        // Update deposit amount or delete if fully consumed
        if (deposit.amount == baseAmount) {
            delete assetDeposits[quoteId];
        } else {
            assetDeposits[quoteId].amount -= baseAmount;
        }

        // Transfer assets to acceptor
        if (baseToken == ETH) {
            (bool success,) = acceptor.call{value: baseAmount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(baseToken).safeTransfer(acceptor, baseAmount);
        }
    }

    /**
     * @dev Transfers quoteToken from acceptor to creator
     */
    function _transferQuoteToken(address acceptor, address creator, address quoteToken, uint256 quoteAmount) private {
        if (quoteToken == ETH) {
            TokenTransfer.sendETH(creator, quoteAmount);
        } else {
            IERC20(quoteToken).safeTransferFrom(acceptor, creator, quoteAmount);
        }
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
