// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";
import "@openzeppelin/access/Ownable.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";

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
     * @dev Enum for cross-chain message types
     */
    enum MessageType {
        DEPOSIT_NOTIFICATION, // Chain A -> Chain B: Notify about locked deposit
        SETTLEMENT_CONFIRMATION // Chain B -> Chain A: Confirm settlement and release tokens
    }

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
        address acceptorOnSourceChain; // Address to receive base tokens on source chain
        address quoteTokenRecipient; // Address to receive quote tokens on destination chain
    }

    /**
     * @dev Mapping to track cross-chain deposits
     * rfqId => CrossChainDeposit details
     */
    mapping(bytes32 => CrossChainDeposit) public crossChainDeposits;

    /**
     * @dev Mapping to track native coin deposits for RFQs
     * rfqId => deposited amount in native coins
     */
    mapping(bytes32 => uint256) public ethDeposits;

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
     * @dev Error thrown when deposit is not expired
     */
    error DepositNotExpired();

    /**
     * @dev Error thrown when caller is not the deposit creator
     */
    error NotDepositCreator();

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
     * @dev Emitted when base tokens are released on source chain after settlement
     * @param rfqId Unique identifier for the cross-chain RFQ
     * @param acceptor Address receiving base tokens on source chain
     * @param baseToken Address of the base token
     * @param baseAmount Amount released
     */
    event BaseTokensReleased(bytes32 indexed rfqId, address indexed acceptor, address baseToken, uint256 baseAmount);

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
        uint256 amount = DepositManager.createDeposit(rfqId, ethDeposits);
        emit ETHDeposited(rfqId, msg.sender, amount);
    }

    /**
     * @dev Withdraw native coins from an unused RFQ deposit
     *
     * @param rfqId Unique identifier for the RFQ
     */
    function withdrawDeposit(bytes32 rfqId) external nonReentrant {
        uint256 amount = DepositManager.withdrawDeposit(rfqId, ethDeposits);
        emit ETHWithdrawn(rfqId, msg.sender, amount);
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
        RFQValidation.validateExecuteParams(creator, baseToken, quoteToken, baseAmount, quoteAmount);
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
     * @dev Initiate a cross-chain deposit for RFQ settlement
     *
     * This function locks tokens on the source chain and sends a message to the destination chain
     * via Wormhole. The acceptor on the destination chain can then settle the RFQ by providing
     * the quote token.
     *
     * @param destChainId Wormhole chain ID of the destination chain
     * @param baseToken Address of the base token (or ETH sentinel)
     * @param quoteToken Address of the quote token expected on destination chain
     * @param baseAmount Amount of base token to lock
     * @param quoteAmount Amount of quote token expected from acceptor
     * @param expiryDuration Duration in seconds until the deposit expires
     * @param acceptorOnSourceChain Address on source chain to receive base tokens
     * @param quoteTokenRecipient Address on destination chain to receive quote tokens
     * @param refundAddress Address on source chain to receive refunds of unused gas
     * @return rfqId Unique identifier for this cross-chain RFQ
     */
    function initiateCrossChainDeposit(
        uint16 destChainId,
        address baseToken,
        address quoteToken,
        uint256 baseAmount,
        uint256 quoteAmount,
        uint256 expiryDuration,
        address acceptorOnSourceChain,
        address quoteTokenRecipient,
        address refundAddress
    ) external payable nonReentrant returns (bytes32 rfqId) {
        // Validate parameters
        if (destChainId == 0) revert InvalidChainId();
        if (trustedContracts[destChainId] == address(0)) revert InvalidChainId();
        if (baseToken == address(0) || quoteToken == address(0)) revert("Invalid token address");
        if (baseAmount == 0 || quoteAmount == 0) revert("Invalid amount");
        if (expiryDuration < MINIMUM_EXPIRY_DURATION) revert ExpiryTooShort();
        if (acceptorOnSourceChain == address(0)) revert("Invalid acceptor address");
        if (quoteTokenRecipient == address(0)) revert("Invalid recipient address");

        // Generate unique RFQ ID
        rfqId = keccak256(
            abi.encodePacked(block.chainid, destChainId, msg.sender, chainNonces[destChainId]++, block.timestamp)
        );

        // Calculate expiry timestamp
        uint256 expiryTimestamp = block.timestamp + expiryDuration;

        // Lock base tokens using TokenTransfer library
        TokenTransfer.lockTokens(baseToken, msg.sender, baseAmount, rfqId, ethDeposits);

        // Store deposit information
        crossChainDeposits[rfqId] = CrossChainDeposit({
            creator: msg.sender,
            baseToken: baseToken,
            quoteToken: quoteToken,
            baseAmount: baseAmount,
            quoteAmount: quoteAmount,
            sourceChainId: uint16(block.chainid),
            destChainId: destChainId,
            expiryTimestamp: expiryTimestamp,
            settled: false,
            acceptorOnSourceChain: acceptorOnSourceChain,
            quoteTokenRecipient: quoteTokenRecipient
        });

        // Send cross-chain message and get sequence
        uint64 sequence = _sendCrossChainMessage(
            destChainId,
            rfqId,
            baseToken,
            quoteToken,
            baseAmount,
            quoteAmount,
            expiryTimestamp,
            acceptorOnSourceChain,
            quoteTokenRecipient,
            refundAddress
        );

        emit CrossChainDepositInitiated(
            rfqId,
            uint16(block.chainid),
            destChainId,
            msg.sender,
            baseToken,
            quoteToken,
            baseAmount,
            quoteAmount,
            expiryTimestamp,
            sequence
        );
    }

    /**
     * @dev Internal function to send cross-chain message via Wormhole
     */
    function _sendCrossChainMessage(
        uint16 destChainId,
        bytes32 rfqId,
        address baseToken,
        address quoteToken,
        uint256 baseAmount,
        uint256 quoteAmount,
        uint256 expiryTimestamp,
        address acceptorOnSourceChain,
        address quoteTokenRecipient,
        address refundAddress
    ) private returns (uint64 sequence) {
        // Encode payload
        bytes memory payload = WormholeCodec.encodeDepositNotification(
            WormholeCodec.DepositNotificationParams({
                rfqId: rfqId,
                creator: msg.sender,
                baseToken: baseToken,
                quoteToken: quoteToken,
                baseAmount: baseAmount,
                quoteAmount: quoteAmount,
                expiryTimestamp: expiryTimestamp,
                acceptorOnSourceChain: acceptorOnSourceChain,
                quoteTokenRecipient: quoteTokenRecipient
            })
        );

        // Calculate Wormhole delivery cost
        (uint256 deliveryCost,) = wormholeRelayer.quoteEVMDeliveryPrice(destChainId, 0, CROSS_CHAIN_GAS_LIMIT);

        // Ensure sufficient payment for Wormhole delivery
        uint256 wormholeFee = baseToken == ETH ? msg.value - baseAmount : msg.value;
        if (wormholeFee < deliveryCost) revert InsufficientWormholeFee();

        // Send message via Wormhole
        sequence = wormholeRelayer.sendPayloadToEvm{value: wormholeFee}(
            destChainId,
            trustedContracts[destChainId],
            payload,
            0,
            CROSS_CHAIN_GAS_LIMIT,
            uint16(block.chainid),
            refundAddress
        );
    }

    /**
     * @dev Quote the cost for initiating a cross-chain deposit (one-way)
     *
     * @param destChainId Wormhole chain ID of the destination chain
     * @return deliveryCost Cost in native gas tokens to send the message
     */
    function quoteCrossChainDeposit(uint16 destChainId) external view returns (uint256 deliveryCost) {
        (deliveryCost,) = wormholeRelayer.quoteEVMDeliveryPrice(
            destChainId,
            0, // receiverValue
            CROSS_CHAIN_GAS_LIMIT
        );
    }

    /**
     * @dev Quote the total cost for a complete cross-chain RFQ (round-trip)
     * This includes both the initial deposit message and the settlement confirmation
     *
     * @param destChainId Wormhole chain ID of the destination chain
     * @return creatorCost Cost for creator to initiate (A->B message)
     * @return acceptorCost Cost for acceptor to settle (B->A message)
     * @return totalCost Total cost across both chains
     */
    function quoteCrossChainRoundTrip(uint16 destChainId)
        external
        view
        returns (uint256 creatorCost, uint256 acceptorCost, uint256 totalCost)
    {
        // Cost for creator: A -> B message
        (creatorCost,) = wormholeRelayer.quoteEVMDeliveryPrice(destChainId, 0, CROSS_CHAIN_GAS_LIMIT);

        // Cost for acceptor: B -> A message (same as A -> B in most cases)
        (acceptorCost,) = wormholeRelayer.quoteEVMDeliveryPrice(uint16(block.chainid), 0, CROSS_CHAIN_GAS_LIMIT);

        totalCost = creatorCost + acceptorCost;
    }

    /**
     * @dev Get detailed information about a cross-chain deposit
     *
     * @param rfqId Unique identifier for the cross-chain RFQ
     * @return deposit Full deposit information
     */
    function getCrossChainDeposit(bytes32 rfqId) external view returns (CrossChainDeposit memory deposit) {
        return crossChainDeposits[rfqId];
    }

    /**
     * @dev Check if a cross-chain deposit is still active (exists and not expired)
     *
     * @param rfqId Unique identifier for the cross-chain RFQ
     * @return isActive True if deposit exists, not settled, and not expired
     */
    function isCrossChainDepositActive(bytes32 rfqId) external view returns (bool isActive) {
        CrossChainDeposit storage deposit = crossChainDeposits[rfqId];
        return deposit.creator != address(0) && !deposit.settled && block.timestamp <= deposit.expiryTimestamp;
    }

    /**
     * @dev Reclaim a cross-chain deposit after expiry
     *
     * This function allows the creator to reclaim their locked tokens if the RFQ
     * was not settled before the expiry timestamp.
     *
     * @param rfqId Unique identifier for the cross-chain RFQ
     */
    function reclaimCrossChainDeposit(bytes32 rfqId) external nonReentrant {
        CrossChainDeposit storage deposit = crossChainDeposits[rfqId];

        // Validate deposit exists and caller is creator
        if (deposit.creator == address(0)) revert DepositNotFound();
        if (deposit.creator != msg.sender) revert NotDepositCreator();
        if (deposit.settled) revert DepositAlreadySettled();
        if (block.timestamp <= deposit.expiryTimestamp) revert DepositNotExpired();

        // Mark as settled to prevent double-reclaim
        deposit.settled = true;

        // Return locked tokens to creator
        if (deposit.baseToken == ETH) {
            TokenTransfer.unlockETH(rfqId, msg.sender, ethDeposits[rfqId], ethDeposits);
        } else {
            IERC20(deposit.baseToken).safeTransfer(msg.sender, deposit.baseAmount);
        }

        emit CrossChainDepositReclaimed(rfqId, msg.sender, deposit.baseToken, deposit.baseAmount);
    }

    /**
     * @dev Receive Wormhole messages (implements IWormholeReceiver)
     *
     * This function is called by the Wormhole relayer to deliver cross-chain messages.
     * It validates the source and routes to appropriate handler based on message type.
     *
     * @param payload Encoded message payload
     * @param sourceAddress Address of the sender contract on source chain
     * @param sourceChain Wormhole chain ID of the source chain
     * @param deliveryHash Unique hash for replay protection
     */
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory,
        /* additionalMessages */
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

        // Decode message type from payload
        uint8 messageType = WormholeCodec.getMessageType(payload);

        if (messageType == uint8(MessageType.DEPOSIT_NOTIFICATION)) {
            _handleDepositNotification(payload, sourceChain);
        } else if (messageType == uint8(MessageType.SETTLEMENT_CONFIRMATION)) {
            _handleSettlementConfirmation(payload);
        } else {
            revert("Invalid message type");
        }
    }

    /**
     * @dev Handle DEPOSIT_NOTIFICATION message from source chain
     */
    function _handleDepositNotification(bytes memory payload, uint16 sourceChain) private {
        // Decode full payload
        WormholeCodec.DepositNotificationParams memory params = WormholeCodec.decodeDepositNotification(payload);

        // Validate expiry
        if (block.timestamp > params.expiryTimestamp) {
            revert ExpiredDeposit();
        }

        // Store information about this cross-chain RFQ on destination chain
        crossChainDeposits[params.rfqId] = CrossChainDeposit({
            creator: params.creator,
            baseToken: params.baseToken,
            quoteToken: params.quoteToken,
            baseAmount: params.baseAmount,
            quoteAmount: params.quoteAmount,
            sourceChainId: sourceChain,
            destChainId: uint16(block.chainid),
            expiryTimestamp: params.expiryTimestamp,
            settled: false,
            acceptorOnSourceChain: params.acceptorOnSourceChain,
            quoteTokenRecipient: params.quoteTokenRecipient
        });

        emit CrossChainSettlementReceived(
            params.rfqId,
            sourceChain,
            params.creator,
            address(0), // acceptor not yet known
            params.baseToken,
            params.quoteToken,
            params.baseAmount,
            params.quoteAmount
        );
    }

    /**
     * @dev Handle SETTLEMENT_CONFIRMATION message from destination chain
     * This releases the locked base tokens to the acceptor on the source chain
     */
    function _handleSettlementConfirmation(bytes memory payload) private {
        // Decode confirmation payload
        WormholeCodec.SettlementConfirmationParams memory params = WormholeCodec.decodeSettlementConfirmation(payload);

        CrossChainDeposit storage deposit = crossChainDeposits[params.rfqId];

        // Validate deposit exists and not already settled
        if (deposit.creator == address(0)) revert DepositNotFound();
        if (deposit.settled) revert DepositAlreadySettled();

        // Mark as settled
        deposit.settled = true;

        // Transfer base tokens to acceptor on source chain
        address acceptor = deposit.acceptorOnSourceChain;
        if (deposit.baseToken == ETH) {
            TokenTransfer.unlockETH(params.rfqId, acceptor, ethDeposits[params.rfqId], ethDeposits);
        } else {
            IERC20(deposit.baseToken).safeTransfer(acceptor, deposit.baseAmount);
        }

        // Emit events for tracking
        emit BaseTokensReleased(params.rfqId, acceptor, deposit.baseToken, deposit.baseAmount);

        emit TradeExecuted(
            params.rfqId,
            deposit.creator,
            acceptor,
            deposit.baseToken,
            deposit.quoteToken,
            deposit.baseAmount,
            deposit.quoteAmount
        );
    }

    /**
     * @dev Accept a cross-chain RFQ by providing the quote token
     *
     * This function is called on the destination chain by an acceptor who wants to
     * complete the cross-chain swap. They provide the quote token and the contract
     * sends a confirmation message back to the source chain to release base tokens.
     *
     * @param rfqId Unique identifier for the cross-chain RFQ
     */
    function acceptCrossChainRFQ(bytes32 rfqId) external payable nonReentrant {
        CrossChainDeposit storage deposit = crossChainDeposits[rfqId];

        // Validate deposit exists on this chain
        if (deposit.creator == address(0)) revert DepositNotFound();
        if (deposit.settled) revert DepositAlreadySettled();
        if (block.timestamp > deposit.expiryTimestamp) revert ExpiredDeposit();

        // Mark as settled
        deposit.settled = true;

        address acceptor = msg.sender;

        // Calculate Wormhole fee for return message
        (uint256 returnMessageCost,) =
            wormholeRelayer.quoteEVMDeliveryPrice(deposit.sourceChainId, 0, CROSS_CHAIN_GAS_LIMIT);

        // Handle quote token payment and Wormhole fee
        uint256 wormholeFee;
        if (deposit.quoteToken == ETH) {
            // Acceptor must send: quoteAmount + Wormhole fee
            uint256 requiredValue = deposit.quoteAmount + returnMessageCost;
            if (msg.value < requiredValue) {
                revert InsufficientWormholeFee();
            }
            wormholeFee = msg.value - deposit.quoteAmount;

            // Send quote ETH to creator's designated recipient
            TokenTransfer.sendETH(deposit.quoteTokenRecipient, deposit.quoteAmount);
        } else {
            // For ERC20, acceptor must send Wormhole fee as msg.value
            if (msg.value < returnMessageCost) {
                revert InsufficientWormholeFee();
            }
            wormholeFee = msg.value;

            // Transfer ERC20 quote tokens to creator's designated recipient
            IERC20(deposit.quoteToken).safeTransferFrom(acceptor, deposit.quoteTokenRecipient, deposit.quoteAmount);
        }

        // Encode settlement confirmation payload
        bytes memory confirmationPayload =
            WormholeCodec.encodeSettlementConfirmation(WormholeCodec.SettlementConfirmationParams({rfqId: rfqId}));

        // Send confirmation message back to source chain
        wormholeRelayer.sendPayloadToEvm{value: wormholeFee}(
            deposit.sourceChainId,
            trustedContracts[deposit.sourceChainId],
            confirmationPayload,
            0,
            CROSS_CHAIN_GAS_LIMIT,
            uint16(block.chainid),
            acceptor // refund unused gas to acceptor
        );

        emit TradeExecuted(
            rfqId,
            deposit.creator,
            acceptor,
            deposit.baseToken,
            deposit.quoteToken,
            deposit.baseAmount,
            deposit.quoteAmount
        );
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
            TokenTransfer.unlockETH(rfqId, acceptor, baseAmount, ethDeposits);
        } else {
            IERC20(baseToken).safeTransferFrom(creator, acceptor, baseAmount);
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
