// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./RFQSettlement.Base.t.sol";

/**
 * @title RFQSettlementERC20Test
 * @dev Tests for ERC20 to ERC20 swaps
 */
contract RFQSettlementERC20Test is RFQSettlementBaseTest {
    /**
     * Test: Successful atomic swap on same chain
     * Critical behavior: Verify that tokens are transferred correctly between parties
     */
    function test_Execute_Success() public {
        bytes32 rfqId = keccak256("test-rfq-1");

        // Creator approves settlement contract to spend base tokens
        vm.prank(creator);
        baseToken.approve(address(settlement), BASE_AMOUNT);

        // Acceptor approves settlement contract to spend quote tokens
        vm.prank(acceptor);
        quoteToken.approve(address(settlement), QUOTE_AMOUNT);

        // Record balances before swap
        uint256 creatorBaseBalanceBefore = baseToken.balanceOf(creator);
        uint256 acceptorBaseBalanceBefore = baseToken.balanceOf(acceptor);
        uint256 creatorQuoteBalanceBefore = quoteToken.balanceOf(creator);
        uint256 acceptorQuoteBalanceBefore = quoteToken.balanceOf(acceptor);

        // Expect TradeExecuted event to be emitted
        vm.expectEmit(true, true, true, true);
        emit TradeExecuted(rfqId, creator, acceptor, address(baseToken), address(quoteToken), BASE_AMOUNT, QUOTE_AMOUNT);

        // Execute swap as acceptor
        vm.prank(acceptor);
        settlement.execute(rfqId, creator, address(baseToken), address(quoteToken), BASE_AMOUNT, QUOTE_AMOUNT);

        // Verify token transfers occurred correctly
        assertEq(
            baseToken.balanceOf(creator), creatorBaseBalanceBefore - BASE_AMOUNT, "Creator should have sent base tokens"
        );
        assertEq(
            baseToken.balanceOf(acceptor),
            acceptorBaseBalanceBefore + BASE_AMOUNT,
            "Acceptor should have received base tokens"
        );
        assertEq(
            quoteToken.balanceOf(creator),
            creatorQuoteBalanceBefore + QUOTE_AMOUNT,
            "Creator should have received quote tokens"
        );
        assertEq(
            quoteToken.balanceOf(acceptor),
            acceptorQuoteBalanceBefore - QUOTE_AMOUNT,
            "Acceptor should have sent quote tokens"
        );
    }

    /**
     * Test: Revert when creator has insufficient base token balance
     * Critical behavior: Prevent swaps when creator cannot fulfill their obligation
     */
    function test_Execute_RevertInsufficientCreatorBalance() public {
        bytes32 rfqId = keccak256("test-rfq-2");

        // Create new creator with insufficient balance
        address poorCreator = makeAddr("poorCreator");
        baseToken.mint(poorCreator, BASE_AMOUNT / 2); // Only half the required amount

        // Poor creator approves settlement contract
        vm.prank(poorCreator);
        baseToken.approve(address(settlement), BASE_AMOUNT);

        // Acceptor approves settlement contract
        vm.prank(acceptor);
        quoteToken.approve(address(settlement), QUOTE_AMOUNT);

        // Attempt to execute swap should revert due to insufficient balance
        vm.prank(acceptor);
        vm.expectRevert();
        settlement.execute(rfqId, poorCreator, address(baseToken), address(quoteToken), BASE_AMOUNT, QUOTE_AMOUNT);
    }

    /**
     * Test: Revert when acceptor has insufficient quote token balance
     * Critical behavior: Prevent swaps when acceptor cannot fulfill their obligation
     */
    function test_Execute_RevertInsufficientAcceptorBalance() public {
        bytes32 rfqId = keccak256("test-rfq-3");

        // Creator approves settlement contract
        vm.prank(creator);
        baseToken.approve(address(settlement), BASE_AMOUNT);

        // Create new acceptor with insufficient balance
        address poorAcceptor = makeAddr("poorAcceptor");
        quoteToken.mint(poorAcceptor, QUOTE_AMOUNT / 2); // Only half the required amount

        // Poor acceptor approves settlement contract
        vm.prank(poorAcceptor);
        quoteToken.approve(address(settlement), QUOTE_AMOUNT);

        // Attempt to execute swap should revert due to insufficient balance
        vm.prank(poorAcceptor);
        vm.expectRevert();
        settlement.execute(rfqId, creator, address(baseToken), address(quoteToken), BASE_AMOUNT, QUOTE_AMOUNT);
    }

    /**
     * Test: Revert when base amount is zero
     * Critical behavior: Prevent invalid swaps with zero amounts
     */
    function test_Execute_RevertZeroBaseAmount() public {
        bytes32 rfqId = keccak256("test-rfq-4");

        // Creator approves settlement contract
        vm.prank(creator);
        baseToken.approve(address(settlement), BASE_AMOUNT);

        // Acceptor approves settlement contract
        vm.prank(acceptor);
        quoteToken.approve(address(settlement), QUOTE_AMOUNT);

        // Attempt to execute swap with zero base amount should revert
        vm.prank(acceptor);
        vm.expectRevert("Invalid amount");
        settlement.execute(
            rfqId,
            creator,
            address(baseToken),
            address(quoteToken),
            0, // Zero base amount
            QUOTE_AMOUNT
        );
    }

    /**
     * Test: Revert when quote amount is zero
     * Critical behavior: Prevent invalid swaps with zero amounts
     */
    function test_Execute_RevertZeroQuoteAmount() public {
        bytes32 rfqId = keccak256("test-rfq-5");

        // Creator approves settlement contract
        vm.prank(creator);
        baseToken.approve(address(settlement), BASE_AMOUNT);

        // Acceptor approves settlement contract
        vm.prank(acceptor);
        quoteToken.approve(address(settlement), QUOTE_AMOUNT);

        // Attempt to execute swap with zero quote amount should revert
        vm.prank(acceptor);
        vm.expectRevert("Invalid amount");
        settlement.execute(
            rfqId,
            creator,
            address(baseToken),
            address(quoteToken),
            BASE_AMOUNT,
            0 // Zero quote amount
        );
    }

    /**
     * Test: Revert when token addresses are zero address
     * Critical behavior: Prevent invalid swaps with invalid token addresses
     */
    function test_Execute_RevertZeroAddressToken() public {
        bytes32 rfqId = keccak256("test-rfq-6");

        // Creator approves settlement contract
        vm.prank(creator);
        baseToken.approve(address(settlement), BASE_AMOUNT);

        // Acceptor approves settlement contract
        vm.prank(acceptor);
        quoteToken.approve(address(settlement), QUOTE_AMOUNT);

        // Attempt to execute swap with zero address for base token should revert
        vm.prank(acceptor);
        vm.expectRevert("Invalid token address");
        settlement.execute(
            rfqId,
            creator,
            address(0), // Zero address for base token
            address(quoteToken),
            BASE_AMOUNT,
            QUOTE_AMOUNT
        );

        // Attempt to execute swap with zero address for quote token should revert
        vm.prank(acceptor);
        vm.expectRevert("Invalid token address");
        settlement.execute(
            rfqId,
            creator,
            address(baseToken),
            address(0), // Zero address for quote token
            BASE_AMOUNT,
            QUOTE_AMOUNT
        );
    }
}
