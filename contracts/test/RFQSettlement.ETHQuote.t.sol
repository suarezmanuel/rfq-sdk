// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./RFQSettlement.Base.t.sol";
import "./mocks/AcceptorHelper.sol";
import "./mocks/MaliciousReceiver.sol";

/**
 * @title RFQSettlementETHQuoteTest
 * @dev Tests for trades where ETH is the quoteToken (acceptor sends ETH)
 */
contract RFQSettlementETHQuoteTest is RFQSettlementBaseTest {
    /**
     * Test: Successful native coin trade (ERC20 → ETH)
     * Critical behavior: Verify native coin trades work end-to-end
     */
    function test_ETH_Success() public {
        bytes32 rfqId = keccak256("test-eth-1");

        // Deploy helper contract to act as acceptor
        AcceptorHelper acceptorHelper = new AcceptorHelper();

        // Creator approves settlement contract to spend base tokens
        vm.prank(creator);
        baseToken.approve(address(settlement), BASE_AMOUNT);

        // Record balances before swap
        uint256 creatorBaseBalanceBefore = baseToken.balanceOf(creator);
        uint256 acceptorBaseBalanceBefore = baseToken.balanceOf(address(acceptorHelper));
        uint256 creatorNativeBalanceBefore = creator.balance;

        // Execute swap via helper contract, sending ETH with the call
        vm.deal(address(this), NATIVE_AMOUNT);
        acceptorHelper.executeTrade{value: NATIVE_AMOUNT}(
            payable(address(settlement)),
            rfqId,
            creator,
            address(baseToken),
            settlement.ETH(),
            BASE_AMOUNT,
            NATIVE_AMOUNT
        );

        // Verify baseToken transfer (creator to acceptor)
        assertEq(
            baseToken.balanceOf(creator), creatorBaseBalanceBefore - BASE_AMOUNT, "Creator should have sent base tokens"
        );
        assertEq(
            baseToken.balanceOf(address(acceptorHelper)),
            acceptorBaseBalanceBefore + BASE_AMOUNT,
            "Acceptor should have received base tokens"
        );

        // Verify native coin transfer (test contract paid, creator received)
        assertEq(
            creator.balance, creatorNativeBalanceBefore + NATIVE_AMOUNT, "Creator should have received native coins"
        );
        // The helper contract should have 0 balance (it just forwarded the ETH)
        assertEq(address(acceptorHelper).balance, 0, "Acceptor helper should have zero balance after forwarding ETH");
    }

    /**
     * Test: msg.value validation when quoteToken is ETH (must match quoteAmount)
     * Critical behavior: Prevent underpayment/overpayment for native coin trades
     */
    function test_ETH_RevertAmountMismatch() public {
        bytes32 rfqId = keccak256("test-eth-2");

        // Deploy helper contract
        AcceptorHelper acceptorHelper = new AcceptorHelper();

        // Creator approves settlement contract
        vm.prank(creator);
        baseToken.approve(address(settlement), BASE_AMOUNT);

        // Give test contract ETH to send
        vm.deal(address(this), NATIVE_AMOUNT * 3);

        // Attempt to execute with msg.value < quoteAmount (underpayment) - should revert
        bool success1;
        try acceptorHelper.executeTrade{value: NATIVE_AMOUNT / 2}(
            payable(address(settlement)),
            rfqId,
            creator,
            address(baseToken),
            settlement.ETH(),
            BASE_AMOUNT,
            NATIVE_AMOUNT
        ) {
            success1 = true;
        } catch {
            success1 = false;
        }
        assertFalse(success1, "Should revert with underpayment");

        // Attempt to execute with msg.value > quoteAmount (overpayment) - should revert
        bool success2;
        try acceptorHelper.executeTrade{value: NATIVE_AMOUNT * 2}(
            payable(address(settlement)),
            rfqId,
            creator,
            address(baseToken),
            settlement.ETH(),
            BASE_AMOUNT,
            NATIVE_AMOUNT
        ) {
            success2 = true;
        } catch {
            success2 = false;
        }
        assertFalse(success2, "Should revert with overpayment");
    }

    /**
     * Test: msg.value validation when quoteToken is ERC20 (must be zero)
     * Critical behavior: Prevent users from accidentally sending ETH with ERC20 trades
     */
    function test_ETH_RevertUnexpectedETHSent() public {
        bytes32 rfqId = keccak256("test-eth-3");

        // Creator approves settlement contract
        vm.prank(creator);
        baseToken.approve(address(settlement), BASE_AMOUNT);

        // Acceptor approves settlement contract for ERC20 quote token
        vm.prank(acceptor);
        quoteToken.approve(address(settlement), QUOTE_AMOUNT);

        // Fund acceptor with ETH
        vm.deal(acceptor, NATIVE_AMOUNT);

        // Attempt to execute ERC20 trade with msg.value > 0 should revert
        vm.prank(acceptor);
        vm.expectRevert(RFQSettlement.UnexpectedETHSent.selector);
        settlement.execute{value: NATIVE_AMOUNT}(
            rfqId,
            creator,
            address(baseToken),
            address(quoteToken), // ERC20 quote token
            BASE_AMOUNT,
            QUOTE_AMOUNT
        );
    }

    /**
     * Test: Revert when native coin transfer to creator fails
     * Critical behavior: Ensure atomic execution when creator cannot receive ETH
     */
    function test_ETH_RevertTransferFailed() public {
        bytes32 rfqId = keccak256("test-eth-4");

        // Deploy helper and malicious receiver contracts
        AcceptorHelper acceptorHelper = new AcceptorHelper();
        MaliciousReceiver maliciousCreator = new MaliciousReceiver();

        // Mint base tokens to malicious contract
        baseToken.mint(address(maliciousCreator), BASE_AMOUNT);

        // Malicious contract approves settlement contract
        vm.prank(address(maliciousCreator));
        baseToken.approve(address(settlement), BASE_AMOUNT);

        // Give test contract ETH to send
        vm.deal(address(this), NATIVE_AMOUNT);

        // Attempt to execute should revert when ETH transfer to malicious contract fails
        bool success;
        try acceptorHelper.executeTrade{value: NATIVE_AMOUNT}(
            payable(address(settlement)),
            rfqId,
            address(maliciousCreator),
            address(baseToken),
            settlement.ETH(),
            BASE_AMOUNT,
            NATIVE_AMOUNT
        ) {
            success = true;
        } catch {
            success = false;
        }
        assertFalse(success, "Should revert when ETH transfer fails");

        // Verify atomic execution: test contract still has their ETH (transaction reverted)
        assertEq(address(this).balance, NATIVE_AMOUNT, "Test contract should still have its ETH after failed trade");

        // Verify atomic execution: acceptor did not receive base tokens (transaction reverted)
        assertEq(
            baseToken.balanceOf(address(acceptorHelper)),
            0,
            "Acceptor should not have received base tokens after failed trade"
        );
    }
}
