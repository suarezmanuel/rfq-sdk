// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";
import "@openzeppelin/access/Ownable.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";

/**
 * @title RFQSettlement
 * @dev Settlement contract for atomic P2P trades.
 *
 * This contract handles RFQ (Request for Quote) settlements using atomic swaps.
 * It validates RFQ terms, transfers baseToken from creator to acceptor, and transfers
 * quoteToken from acceptor to creator in a single transaction.
 */
contract RFQSettlement is ReentrancyGuard, Ownable, IWormholeReceiver {
    using SafeERC20 for IERC20;

    uint256 public constant VERSION = 0;

    /**
     * @dev Sentinel address representing native coins across all EVM chains
     * This address is the EVM standard for native coins (ETH, MATIC, AVAX, etc.)
     * Works identically on Ethereum, Polygon, Avalanche, Base, and all EVM chains
     */
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /**
     * @dev Minimum expiry duration for cross-chain deposits (15 minutes)
     * Prevents too-short timeouts that could result in failed settlements
     */
    uint256 public constant MINIMUM_EXPIRY_DURATION = 15 minutes;

    /**
     * @dev Gas limit for cross-chain message execution on destination chain
     * Set to 300,000 gas to cover token transfers and settlement logic
     */
    uint256 public constant CROSS_CHAIN_GAS_LIMIT = 300000;

    /**
     * @dev Wormhole relayer contract for sending and receiving cross-chain messages
     */
    IWormholeRelayer public immutable wormholeRelayer;

    /**
     * @dev Struct containing cross-chain deposit information
     */
    struct CrossChainDeposit {
        address creator; // Address that created the deposit
        address baseToken; // Token being sold by creator
        address quoteToken; // Token being bought from acceptor
        uint256 baseAmount; // Amount of base token
        uint256 quoteAmount; // Amount of quote token
        uint16 sourceChainId; // Wormhole chain ID of source chain
        uint16 destChainId; // Wormhole chain ID of destination chain
        uint256 expiryTimestamp; // Timestamp after which deposit can be reclaimed
        bool settled; // Whether the deposit has been settled
    }

    /**
     * @dev Mapping to track cross-chain deposits
     * rfqId => CrossChainDeposit details
     */
    mapping(bytes32 => CrossChainDeposit) public crossChainDeposits;

    /**
     * @dev Mapping to track trusted contract addresses on other chains
     * wormholeChainId => trusted contract address
     */
    mapping(uint16 => address) public trustedContracts;

    /**
     * @dev Mapping to prevent replay attacks on cross-chain messages
     * deliveryHash => consumed status
     */
    mapping(bytes32 => bool) public consumedMessages;

    /**
     * @dev Mapping to track nonces for generating unique cross-chain RFQ IDs
     * chainId => nonce
     */
    mapping(uint16 => uint256) public chainNonces;

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
     * @dev Error thrown when an invalid chain ID is provided
     */
    error InvalidChainId();

    /**
     * @dev Error thrown when attempting to settle an expired deposit
     */
    error ExpiredDeposit();

    /**
     * @dev Error thrown when insufficient Wormhole delivery fee is provided
     */
    error InsufficientWormholeFee();

    /**
     * @dev Error thrown when message is received from an unauthorized Wormhole source
     */
    error UnauthorizedWormholeSource();

    /**
     * @dev Error thrown when deposit is not found
     */
    error DepositNotFound();

    /**
     * @dev Error thrown when attempting to reclaim or settle an already settled deposit
     */
    error DepositAlreadySettled();

    /**
     * @dev Error thrown when expiry duration is too short
     */
    error ExpiryTooShort();

    /**
     * @dev Error thrown when attempting to process an already processed message
     */
    error MessageAlreadyProcessed();

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
     * @dev Emitted when a cross-chain deposit is initiated
     * @param rfqId Unique identifier for the cross-chain RFQ
     * @param sourceChainId Wormhole chain ID of the source chain
     * @param destChainId Wormhole chain ID of the destination chain
     * @param creator Address of the deposit creator
     * @param baseToken Address of the base token
     * @param quoteToken Address of the quote token
     * @param baseAmount Amount of base token deposited
     * @param quoteAmount Amount of quote token expected
     * @param expiryTimestamp Timestamp after which deposit can be reclaimed
     * @param wormholeSequence Wormhole message sequence number for tracking
     */
    event CrossChainDepositInitiated(
        bytes32 indexed rfqId,
        uint16 sourceChainId,
        uint16 destChainId,
        address indexed creator,
        address baseToken,
        address quoteToken,
        uint256 baseAmount,
        uint256 quoteAmount,
        uint256 expiryTimestamp,
        uint64 wormholeSequence
    );

    /**
     * @dev Emitted when a cross-chain settlement is received and executed
     * @param rfqId Unique identifier for the cross-chain RFQ
     * @param sourceChainId Wormhole chain ID of the source chain
     * @param creator Address of the RFQ creator (on source chain)
     * @param acceptor Address of the RFQ acceptor (on destination chain)
     * @param baseToken Address of the base token
     * @param quoteToken Address of the quote token
     * @param baseAmount Amount of base token transferred
     * @param quoteAmount Amount of quote token transferred
     */
    event CrossChainSettlementReceived(
        bytes32 indexed rfqId,
        uint16 sourceChainId,
        address indexed creator,
        address indexed acceptor,
        address baseToken,
        address quoteToken,
        uint256 baseAmount,
        uint256 quoteAmount
    );

    /**
     * @dev Emitted when an expired cross-chain deposit is reclaimed
     * @param rfqId Unique identifier for the cross-chain RFQ
     * @param creator Address of the deposit creator
     * @param baseToken Address of the base token
     * @param baseAmount Amount of base token reclaimed
     */
    event CrossChainDepositReclaimed(
        bytes32 indexed rfqId, address indexed creator, address baseToken, uint256 baseAmount
    );

    /**
     * @dev Emitted when a trusted contract is registered for a chain
     * @param chainId Wormhole chain ID
     * @param contractAddress Trusted contract address on that chain
     */
    event TrustedContractSet(uint16 indexed chainId, address contractAddress);

    /**
     * @dev Constructor
     * @param _wormholeRelayer Address of the Wormhole relayer contract
     */
    constructor(address _wormholeRelayer) Ownable(msg.sender) {
        require(_wormholeRelayer != address(0), "Invalid relayer address");
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
    }

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
        _validateExecute(creator, baseToken, quoteToken, baseAmount, quoteAmount);
        _validateMsgValue(quoteToken, quoteAmount);

        address acceptor = msg.sender;

        _transferBaseToken(rfqId, creator, acceptor, baseToken, baseAmount);
        _transferQuoteToken(acceptor, creator, quoteToken, quoteAmount);

        emit TradeExecuted(rfqId, creator, acceptor, baseToken, quoteToken, baseAmount, quoteAmount);
    }

    /**
     * @dev Set trusted contract address for a specific chain (owner only)
     *
     * @param chainId Wormhole chain ID
     * @param contractAddress Trusted contract address on that chain
     */
    function setTrustedContract(uint16 chainId, address contractAddress) external onlyOwner {
        require(chainId != 0, "Invalid chain ID");
        require(contractAddress != address(0), "Invalid contract address");

        trustedContracts[chainId] = contractAddress;
        emit TrustedContractSet(chainId, contractAddress);
    }

    /**
     * @dev Receive Wormhole messages (implements IWormholeReceiver)
     *
     * This function is called by the Wormhole relayer to deliver cross-chain messages.
     * It validates the source and processes the settlement.
     *
     * @param payload Encoded message payload
     * @param additionalMessages Additional messages (unused in this implementation)
     * @param sourceAddress Address of the sender contract on source chain
     * @param sourceChain Wormhole chain ID of the source chain
     * @param deliveryHash Unique hash for replay protection
     */
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory additionalMessages,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) external payable override nonReentrant {
        // Validate caller is Wormhole relayer
        if (msg.sender != address(wormholeRelayer)) {
            revert UnauthorizedWormholeSource();
        }

        // Validate source contract is trusted
        address expectedSource = trustedContracts[sourceChain];
        address actualSource = address(uint160(uint256(sourceAddress)));
        if (actualSource != expectedSource || expectedSource == address(0)) {
            revert UnauthorizedWormholeSource();
        }

        // Prevent replay attacks
        if (consumedMessages[deliveryHash]) {
            revert MessageAlreadyProcessed();
        }
        consumedMessages[deliveryHash] = true;

        // Decode payload and process settlement
        // This will be implemented in Task Group 3
        // For now, this satisfies the interface requirement
    }

    /**
     * @dev Validates execute parameters
     */
    function _validateExecute(
        address creator,
        address baseToken,
        address quoteToken,
        uint256 baseAmount,
        uint256 quoteAmount
    ) private pure {
        require(baseToken != address(0) && quoteToken != address(0), "Invalid token address");
        require(baseAmount > 0 && quoteAmount > 0, "Invalid amount");
        require(creator != address(0), "Invalid creator address");
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
    function _transferBaseToken(bytes32 rfqId, address creator, address acceptor, address baseToken, uint256 baseAmount)
        private
    {
        if (baseToken == ETH) {
            _transferETHFromDeposit(rfqId, acceptor, baseAmount);
        } else {
            IERC20(baseToken).safeTransferFrom(creator, acceptor, baseAmount);
        }
    }

    /**
     * @dev Transfers quoteToken from acceptor to creator
     */
    function _transferQuoteToken(address acceptor, address creator, address quoteToken, uint256 quoteAmount) private {
        if (quoteToken == ETH) {
            _sendETH(creator, quoteAmount);
        } else {
            IERC20(quoteToken).safeTransferFrom(acceptor, creator, quoteAmount);
        }
    }

    /**
     * @dev Transfers ETH from deposit to recipient
     */
    function _transferETHFromDeposit(bytes32 rfqId, address recipient, uint256 amount) private {
        if (ethDeposits[rfqId] < amount) revert InsufficientETHDeposit();

        ethDeposits[rfqId] -= amount;
        _sendETH(recipient, amount);
    }

    /**
     * @dev Sends ETH to recipient with proper error handling
     */
    function _sendETH(address recipient, uint256 amount) private {
        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert ETHTransferFailed();
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
