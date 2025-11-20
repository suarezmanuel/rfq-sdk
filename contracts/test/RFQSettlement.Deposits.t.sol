// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./RFQSettlement.Base.t.sol";

/**
 * @title RFQSettlementDepositsTest
 * @dev Tests for ETH deposit and withdrawal functionality
 */
contract RFQSettlementDepositsTest is RFQSettlementBaseTest {
    /**
     * Test: Successful deposit and withdrawal of native coins
     * Critical behavior: Verify deposit/withdrawal functions work correctly
     */
    function test_Deposit_Success() public {
        bytes32 rfqId = keccak256("test-deposit-1");

        // Fund creator with ETH
        vm.deal(creator, NATIVE_AMOUNT * 2);

        // Record balance before deposit
        uint256 creatorBalanceBefore = creator.balance;

        // Creator deposits native coins
        vm.prank(creator);
        settlement.depositForRFQ{value: NATIVE_AMOUNT}(rfqId);

        // Verify deposit was recorded
        assertEq(settlement.ethDeposits(rfqId), NATIVE_AMOUNT, "Deposit should be recorded");
        assertEq(creator.balance, creatorBalanceBefore - NATIVE_AMOUNT, "Creator balance should decrease");

        // Withdraw the deposit
        vm.prank(creator);
        settlement.withdrawDeposit(rfqId);

        // Verify withdrawal cleared the deposit and returned funds
        assertEq(settlement.ethDeposits(rfqId), 0, "Deposit should be cleared");
        assertEq(creator.balance, creatorBalanceBefore, "Creator should have received funds back");
    }

    /**
     * Test: Revert when trying to withdraw non-existent deposit
     * Critical behavior: Prevent withdrawal of deposits that don't exist
     */
    function test_Deposit_RevertNoDeposit() public {
        bytes32 rfqId = keccak256("test-no-deposit");

        // Attempt to withdraw without having deposited
        vm.prank(creator);
        vm.expectRevert(RFQSettlement.NoDepositFound.selector);
        settlement.withdrawDeposit(rfqId);
    }

    /**
     * Test: Revert when trying to deposit zero native coins
     * Critical behavior: Prevent invalid deposits
     */
    function test_Deposit_RevertZeroDeposit() public {
        bytes32 rfqId = keccak256("test-zero-deposit");

        // Attempt to deposit zero should revert
        vm.prank(creator);
        vm.expectRevert(RFQSettlement.InvalidDepositAmount.selector);
        settlement.depositForRFQ{value: 0}(rfqId);
    }
}
