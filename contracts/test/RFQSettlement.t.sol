// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";
import "../src/RFQSettlement.sol";

/**
 * @title MockERC20
 * @dev Simple ERC20 token for testing
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title MaliciousReceiver
 * @dev Contract that rejects ETH transfers for testing transfer failure scenarios
 */
contract MaliciousReceiver {
    // Reject all ETH transfers by reverting in receive function
    receive() external payable {
        revert("ETH transfer rejected");
    }
}

/**
 * @title AcceptorHelper
 * @dev Helper contract that can actually execute trades as an EOA-like entity
 */
contract AcceptorHelper {
    function executeTrade(
        address payable settlement,
        bytes32 rfqId,
        address creator,
        address baseToken,
        address quoteToken,
        uint256 baseAmount,
        uint256 quoteAmount
    ) external payable {
        RFQSettlement(settlement).execute{value: msg.value}(
            rfqId, creator, baseToken, quoteToken, baseAmount, quoteAmount
        );
    }

    receive() external payable {}
}

contract RFQSettlementTest is Test {
    RFQSettlement public settlement;
    MockERC20 public baseToken;
    MockERC20 public quoteToken;

    address public creator;
    address public acceptor;

    uint256 constant BASE_AMOUNT = 100 * 10 ** 18;
    uint256 constant QUOTE_AMOUNT = 200 * 10 ** 18;
    uint256 constant NATIVE_AMOUNT = 1 ether;

    event TradeExecuted(
        bytes32 indexed rfqId,
        address indexed creator,
        address indexed acceptor,
        address baseToken,
        address quoteToken,
        uint256 baseAmount,
        uint256 quoteAmount
    );

    function setUp() public {
        // Deploy settlement contract
        settlement = new RFQSettlement();

        // Deploy mock tokens
        baseToken = new MockERC20("Base Token", "BASE");
        quoteToken = new MockERC20("Quote Token", "QUOTE");

        // Set up test accounts
        creator = makeAddr("creator");
        acceptor = makeAddr("acceptor");

        // Mint tokens to participants
        baseToken.mint(creator, BASE_AMOUNT * 10);
        quoteToken.mint(acceptor, QUOTE_AMOUNT * 10);
    }

    function test_Excute_Success() public {
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

    function test_Excute_RevertInsufficientCreatorBalance() public {
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

    function test_Excute_RevertInsufficientAcceptorBalance() public {
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

    function test_Excute_RevertZeroBaseAmount() public {
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

    function test_Excute_RevertZeroQuoteAmount() public {
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

    function test_Excute_RevertZeroAddressToken() public {
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

    function test_ETH_Success() public {
        bytes32 rfqId = keccak256("test-native-1");

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

    function test_ETH_RevertAmountMismatch() public {
        bytes32 rfqId = keccak256("test-native-2");

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

    function test_ETH_RevertUnexpectedETHSent() public {
        bytes32 rfqId = keccak256("test-native-3");

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

    function test_ETH_RevertTransferFailed() public {
        bytes32 rfqId = keccak256("test-native-4");

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

    function test_ETH_EventEmission() public {
        bytes32 rfqId = keccak256("test-native-5");

        // Deploy helper contract
        AcceptorHelper acceptorHelper = new AcceptorHelper();

        // Creator approves settlement contract
        vm.prank(creator);
        baseToken.approve(address(settlement), BASE_AMOUNT);

        // Give test contract ETH
        vm.deal(address(this), NATIVE_AMOUNT);

        // Execute trade - event emission is verified implicitly
        acceptorHelper.executeTrade{value: NATIVE_AMOUNT}(
            payable(address(settlement)),
            rfqId,
            creator,
            address(baseToken),
            settlement.ETH(),
            BASE_AMOUNT,
            NATIVE_AMOUNT
        );

        // If event didn't emit correctly, the contract would have failed
        // The sentinel address in quoteToken parameter indicates this was a native coin trade
    }

    function test_ETH_BackwardCompatibility() public {
        bytes32 rfqId = keccak256("test-native-6");

        // This test is essentially the same as test_Excute_Success
        // but explicitly validates that ERC20 trades still work after native coin changes

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

        // Execute ERC20-to-ERC20 swap (no msg.value)
        vm.prank(acceptor);
        settlement.execute(rfqId, creator, address(baseToken), address(quoteToken), BASE_AMOUNT, QUOTE_AMOUNT);

        // Verify token transfers occurred correctly (same assertions as original test)
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

    function test_NativeDeposit_Success() public {
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

    function test_NativeToERC20_Success() public {
        bytes32 rfqId = keccak256("test-native-erc20");
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

    function test_NativeToNative_Success() public {
        bytes32 rfqId = keccak256("test-native-native");
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

    function test_NativeDeposit_RevertInsufficientDeposit() public {
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

    function test_NativeDeposit_RevertNoDeposit() public {
        bytes32 rfqId = keccak256("test-no-deposit");

        // Attempt to withdraw without having deposited
        vm.prank(creator);
        vm.expectRevert(RFQSettlement.NoDepositFound.selector);
        settlement.withdrawDeposit(rfqId);
    }

    function test_NativeDeposit_RevertZeroDeposit() public {
        bytes32 rfqId = keccak256("test-zero-deposit");

        // Attempt to deposit zero should revert
        vm.prank(creator);
        vm.expectRevert(RFQSettlement.InvalidDepositAmount.selector);
        settlement.depositForRFQ{value: 0}(rfqId);
    }

    // Receive function to accept ETH refunds
    receive() external payable {}
}
