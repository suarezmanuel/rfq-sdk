// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title WormholeCodec
 * @dev Library for encoding and decoding Wormhole cross-chain messages
 *
 * This library handles all message serialization for cross-chain RFQ settlements.
 * It provides type-safe encoding and decoding of DEPOSIT_NOTIFICATION and
 * SETTLEMENT_CONFIRMATION message types.
 */
library WormholeCodec {
    /**
     * @dev Enum for cross-chain message types
     */
    enum MessageType {
        DEPOSIT_NOTIFICATION, // Chain A -> Chain B: Notify about locked deposit
        SETTLEMENT_CONFIRMATION // Chain B -> Chain A: Confirm settlement and release tokens
    }

    /**
     * @dev Parameters for DEPOSIT_NOTIFICATION message
     */
    struct DepositNotificationParams {
        bytes32 rfqId;
        address creator;
        address baseToken;
        address quoteToken;
        uint256 baseAmount;
        uint256 quoteAmount;
        uint256 expiryTimestamp;
        address acceptorOnSourceChain;
        address quoteTokenRecipient;
    }

    /**
     * @dev Parameters for SETTLEMENT_CONFIRMATION message
     */
    struct SettlementConfirmationParams {
        bytes32 rfqId;
    }

    /**
     * @dev Encode DEPOSIT_NOTIFICATION message for cross-chain transmission
     *
     * This function creates the payload sent from source chain to destination chain
     * to notify about a locked deposit awaiting settlement.
     *
     * @param params Deposit notification parameters
     * @return Encoded payload ready for Wormhole transmission
     */
    function encodeDepositNotification(DepositNotificationParams memory params)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(
            uint8(MessageType.DEPOSIT_NOTIFICATION),
            params.rfqId,
            params.creator,
            params.baseToken,
            params.quoteToken,
            params.baseAmount,
            params.quoteAmount,
            params.expiryTimestamp,
            params.acceptorOnSourceChain,
            params.quoteTokenRecipient
        );
    }

    /**
     * @dev Decode DEPOSIT_NOTIFICATION message received from source chain
     *
     * This function parses the payload received on the destination chain
     * and extracts all deposit parameters.
     *
     * @param payload Encoded message payload from Wormhole
     * @return params Decoded deposit notification parameters
     */
    function decodeDepositNotification(bytes memory payload)
        internal
        pure
        returns (DepositNotificationParams memory params)
    {
        (, // skip message type
            params.rfqId,
            params.creator,
            params.baseToken,
            params.quoteToken,
            params.baseAmount,
            params.quoteAmount,
            params.expiryTimestamp,
            params.acceptorOnSourceChain,
            params.quoteTokenRecipient
        ) = abi.decode(
            payload, (uint8, bytes32, address, address, address, uint256, uint256, uint256, address, address)
        );
    }

    /**
     * @dev Encode SETTLEMENT_CONFIRMATION message for return transmission
     *
     * This function creates the payload sent from destination chain back to source chain
     * to confirm settlement and trigger release of locked base tokens.
     *
     * @param params Settlement confirmation parameters
     * @return Encoded payload ready for Wormhole transmission
     */
    function encodeSettlementConfirmation(SettlementConfirmationParams memory params)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(uint8(MessageType.SETTLEMENT_CONFIRMATION), params.rfqId);
    }

    /**
     * @dev Decode SETTLEMENT_CONFIRMATION message received from destination chain
     *
     * This function parses the confirmation payload received on the source chain
     * and extracts the RFQ ID to release locked tokens.
     *
     * @param payload Encoded message payload from Wormhole
     * @return params Decoded settlement confirmation parameters
     */
    function decodeSettlementConfirmation(bytes memory payload)
        internal
        pure
        returns (SettlementConfirmationParams memory params)
    {
        (, params.rfqId) = abi.decode(payload, (uint8, bytes32));
    }

    /**
     * @dev Extract message type from payload
     *
     * This function reads the first byte of the payload to determine
     * which message type handler should process it.
     *
     * @param payload Encoded message payload
     * @return Message type as uint8
     */
    function getMessageType(bytes memory payload) internal pure returns (uint8) {
        return abi.decode(payload, (uint8));
    }
}
