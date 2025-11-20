// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./RFQSettlement.Base.t.sol";

/**
 * @title RFQSettlementETHBaseTest
 * @dev Tests for trades where ETH is the baseToken (creator deposits ETH)
 */
contract RFQSettlementETHBaseTest is RFQSettlementBaseTest {
    /**
     * Test: Native → ERC20 trade (creator deposits native, acceptor sends ERC20)
     * Critical behavior: Verify creator can offer native coins
     */
    function test_ETHBase_ToERC20_Success() public {
        bytes32 rfqId = keccak256("test-eth-base-erc20");
        address nativeCoin = settlement.ETH();

        // Fund creator with ETH and deposit
        vm.deal(creator, NATIVE_AMOUNT);
        vm.prank(creator);
        settlement.depositForRFQ{value: NATIVE_AMOUNT}(rfqId);

        // Acceptor approves settlement contract to spend quote tokens
        vm.prank(acceptor);
        quoteToken.approve(address(settlement), QUOTE_AMOUNT);

        // Record balances before swap
        uint256 creatorNativeBalanceBefore = creator.balance;
        uint256 acceptorNativeBalanceBefore = acceptor.balance;
        uint256 creatorQuoteBalanceBefore = quoteToken.balanceOf(creator);
        uint256 acceptorQuoteBalanceBefore = quoteToken.balanceOf(acceptor);

        // Execute swap as acceptor (ERC20 → Native baseToken)
        vm.prank(acceptor);
        settlement.execute(
            rfqId,
            creator,
            nativeCoin, // Native baseToken
            address(quoteToken), // ERC20 quoteToken
            NATIVE_AMOUNT,
            QUOTE_AMOUNT
        );

        // Verify native coin transfer (creator's deposit → acceptor)
        assertEq(acceptor.balance, acceptorNativeBalanceBefore + NATIVE_AMOUNT, "Acceptor should receive native coins");
        assertEq(creator.balance, creatorNativeBalanceBefore, "Creator balance unchanged (used deposit)");
        assertEq(settlement.ethDeposits(rfqId), 0, "Deposit should be cleared after execution");

        // Verify ERC20 transfer (acceptor → creator)
        assertEq(
            quoteToken.balanceOf(creator),
            creatorQuoteBalanceBefore + QUOTE_AMOUNT,
            "Creator should receive quote tokens"
        );
        assertEq(
            quoteToken.balanceOf(acceptor),
            acceptorQuoteBalanceBefore - QUOTE_AMOUNT,
            "Acceptor should send quote tokens"
        );
    }

    /**
     * Test: Native → Native trade (creator deposits native, acceptor sends native)
     * Critical behavior: Verify native-to-native swaps work for cross-chain scenarios
     */
    function test_ETHBase_ToNative_Success() public {
        bytes32 rfqId = keccak256("test-eth-base-native");
        address nativeCoin = settlement.ETH();

        // Fund creator with ETH and deposit
        vm.deal(creator, NATIVE_AMOUNT);
        vm.prank(creator);
        settlement.depositForRFQ{value: NATIVE_AMOUNT}(rfqId);

        // Fund acceptor with ETH
        vm.deal(acceptor, QUOTE_AMOUNT + 1 ether); // Extra for gas

        // Record balances before swap
        uint256 creatorBalanceBefore = creator.balance;
        uint256 acceptorBalanceBefore = acceptor.balance;

        // Execute swap as acceptor (Native → Native)
        vm.prank(acceptor);
        settlement.execute{value: QUOTE_AMOUNT}(
            rfqId,
            creator,
            nativeCoin, // Native baseToken
            nativeCoin, // Native quoteToken
            NATIVE_AMOUNT,
            QUOTE_AMOUNT
        );

        // Verify native coin transfers
        // Creator receives QUOTE_AMOUNT from acceptor
        assertEq(creator.balance, creatorBalanceBefore + QUOTE_AMOUNT, "Creator should receive quote amount in native");
        // Acceptor receives NATIVE_AMOUNT from creator's deposit
        assertEq(
            acceptor.balance,
            acceptorBalanceBefore - QUOTE_AMOUNT + NATIVE_AMOUNT,
            "Acceptor should send quote and receive base"
        );
        assertEq(settlement.ethDeposits(rfqId), 0, "Deposit should be cleared after execution");
    }

    /**
     * Test: Revert when trying to execute with insufficient native deposit
     * Critical behavior: Prevent execution when creator hasn't deposited enough
     */
    function test_ETHBase_RevertInsufficientDeposit() public {
        bytes32 rfqId = keccak256("test-insufficient-deposit");
        address nativeCoin = settlement.ETH();

        // Fund creator with ETH but deposit less than required
        vm.deal(creator, NATIVE_AMOUNT);
        vm.prank(creator);
        settlement.depositForRFQ{value: NATIVE_AMOUNT / 2}(rfqId); // Only deposit half

        // Acceptor approves settlement contract
        vm.prank(acceptor);
        quoteToken.approve(address(settlement), QUOTE_AMOUNT);

        // Attempt to execute should revert due to insufficient deposit
        vm.prank(acceptor);
        vm.expectRevert(RFQSettlement.InsufficientETHDeposit.selector);
        settlement.execute(
            rfqId,
            creator,
            nativeCoin, // Native baseToken
            address(quoteToken), // ERC20 quoteToken
            NATIVE_AMOUNT, // Requires NATIVE_AMOUNT but only NATIVE_AMOUNT/2 deposited
            QUOTE_AMOUNT
        );
    }
}
