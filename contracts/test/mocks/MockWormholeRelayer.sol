// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";

/**
 * @title MockWormholeRelayer
 * @dev Mock implementation of Wormhole relayer for testing
 */
contract MockWormholeRelayer is IWormholeRelayer {
    uint64 private _sequenceCounter;
    uint256 public constant BASE_DELIVERY_PRICE = 0.01 ether;

    event MessageSent(
        uint16 targetChain,
        address targetAddress,
        bytes payload,
        uint256 receiverValue,
        uint256 gasLimit,
        uint64 sequence
    );

    /**
     * @dev Mock implementation of sendPayloadToEvm (simple version)
     */
    function sendPayloadToEvm(
        uint16 targetChain,
        address targetAddress,
        bytes memory payload,
        uint256 receiverValue,
        uint256 gasLimit
    ) external payable override returns (uint64 sequence) {
        require(msg.value >= BASE_DELIVERY_PRICE, "Insufficient delivery fee");

        sequence = ++_sequenceCounter;

        emit MessageSent(targetChain, targetAddress, payload, receiverValue, gasLimit, sequence);

        return sequence;
    }

    /**
     * @dev Mock implementation of sendPayloadToEvm (with refund parameters)
     */
    function sendPayloadToEvm(
        uint16 targetChain,
        address targetAddress,
        bytes memory payload,
        uint256 receiverValue,
        uint256 gasLimit,
        uint16 refundChain,
        address refundAddress
    ) external payable override returns (uint64 sequence) {
        require(msg.value >= BASE_DELIVERY_PRICE, "Insufficient delivery fee");

        sequence = ++_sequenceCounter;

        emit MessageSent(targetChain, targetAddress, payload, receiverValue, gasLimit, sequence);

        return sequence;
    }

    /**
     * @dev Mock implementation of quoteEVMDeliveryPrice (simple version)
     */
    function quoteEVMDeliveryPrice(uint16, uint256, uint256)
        external
        pure
        override
        returns (uint256 nativePriceQuote, uint256 targetChainRefundPerGasUnused)
    {
        nativePriceQuote = BASE_DELIVERY_PRICE;
        targetChainRefundPerGasUnused = 1 gwei;
        return (nativePriceQuote, targetChainRefundPerGasUnused);
    }

    /**
     * @dev Mock implementation of quoteEVMDeliveryPrice (with delivery provider)
     */
    function quoteEVMDeliveryPrice(uint16, uint256, uint256, address)
        external
        pure
        override
        returns (uint256 nativePriceQuote, uint256 targetChainRefundPerGasUnused)
    {
        nativePriceQuote = BASE_DELIVERY_PRICE;
        targetChainRefundPerGasUnused = 1 gwei;
        return (nativePriceQuote, targetChainRefundPerGasUnused);
    }

    // not needed for basic testing
    function sendVaasToEvm(uint16, address, bytes memory, uint256, uint256, VaaKey[] memory)
        external
        payable
        override
        returns (uint64)
    {
        revert("Not implemented");
    }

    function sendVaasToEvm(uint16, address, bytes memory, uint256, uint256, VaaKey[] memory, uint16, address)
        external
        payable
        override
        returns (uint64)
    {
        revert("Not implemented");
    }

    function sendToEvm(
        uint16,
        address,
        bytes memory,
        uint256,
        uint256,
        uint256,
        uint16,
        address,
        address,
        VaaKey[] memory,
        uint8
    ) external payable override returns (uint64) {
        revert("Not implemented");
    }

    function sendToEvm(
        uint16,
        address,
        bytes memory,
        uint256,
        uint256,
        uint256,
        uint16,
        address,
        address,
        MessageKey[] memory,
        uint8
    ) external payable override returns (uint64) {
        revert("Not implemented");
    }

    function send(
        uint16,
        bytes32,
        bytes memory,
        uint256,
        uint256,
        bytes memory,
        uint16,
        bytes32,
        address,
        VaaKey[] memory,
        uint8
    ) external payable override returns (uint64) {
        revert("Not implemented");
    }

    function send(
        uint16,
        bytes32,
        bytes memory,
        uint256,
        uint256,
        bytes memory,
        uint16,
        bytes32,
        address,
        MessageKey[] memory,
        uint8
    ) external payable override returns (uint64) {
        revert("Not implemented");
    }

    function resendToEvm(VaaKey memory, uint16, uint256, uint256, address) external payable override returns (uint64) {
        revert("Not implemented");
    }

    function resend(VaaKey memory, uint16, uint256, bytes memory, address) external payable override returns (uint64) {
        revert("Not implemented");
    }

    function quoteDeliveryPrice(uint16, uint256, bytes memory, address)
        external
        view
        override
        returns (uint256, bytes memory)
    {
        revert("Not implemented");
    }

    function quoteNativeForChain(uint16, uint256, address) external view override returns (uint256) {
        revert("Not implemented");
    }

    function getDefaultDeliveryProvider() external view override returns (address) {
        return address(this);
    }

    function getRegisteredWormholeRelayerContract(uint16) external view override returns (bytes32) {
        return bytes32(uint256(uint160(address(this))));
    }

    function deliveryAttempted(bytes32) external view override returns (bool) {
        return false;
    }

    function deliverySuccessBlock(bytes32) external view override returns (uint256) {
        return 0;
    }

    function deliveryFailureBlock(bytes32) external view override returns (uint256) {
        return 0;
    }

    function deliver(bytes[] memory, bytes memory, address payable, bytes memory) external payable override {
        revert("Not implemented");
    }
}
