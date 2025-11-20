// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title RFQValidation
 * @dev Library for consolidated validation logic used throughout RFQSettlement contract
 *
 * This library extracts and consolidates all validation patterns to eliminate duplication
 * and provide consistent error handling across the contract.
 *
 * Note: All custom errors are defined in the main RFQSettlement contract.
 * This library references those errors through require statements or direct reverts.
 */
library RFQValidation {
    /**
     * @dev Validate token addresses are not zero
     *
     * @param baseToken Address of the base token
     * @param quoteToken Address of the quote token
     */
    function validateTokenAddresses(address baseToken, address quoteToken) internal pure {
        require(baseToken != address(0) && quoteToken != address(0), "Invalid token address");
    }

    /**
     * @dev Validate amounts are not zero
     *
     * @param baseAmount Amount of base token
     * @param quoteAmount Amount of quote token
     */
    function validateAmounts(uint256 baseAmount, uint256 quoteAmount) internal pure {
        require(baseAmount > 0 && quoteAmount > 0, "Invalid amount");
    }

    /**
     * @dev Validate creator address is not zero
     *
     * @param creator Address of the RFQ creator
     */
    function validateCreatorAddress(address creator) internal pure {
        require(creator != address(0), "Invalid creator address");
    }

    /**
     * @dev Validate RFQ execution parameters
     *
     * @param creator Address of the RFQ creator
     * @param baseToken Address of the base token
     * @param quoteToken Address of the quote token
     * @param baseAmount Amount of base token
     * @param quoteAmount Amount of quote token
     */
    function validateExecuteParams(
        address creator,
        address baseToken,
        address quoteToken,
        uint256 baseAmount,
        uint256 quoteAmount
    ) internal pure {
        validateTokenAddresses(baseToken, quoteToken);
        validateAmounts(baseAmount, quoteAmount);
        validateCreatorAddress(creator);
    }
}
