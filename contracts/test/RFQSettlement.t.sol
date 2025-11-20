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
 * @title RFQSettlementTest
 * @dev Test suite for RFQSettlement contract focusing on critical behaviors
 *
 * Test Coverage:
 * 1. Atomic swap flow (same-chain)
 * 2. Token transfer validation
 * 3. Revert scenarios (insufficient balance, invalid amounts)
 */
contract RFQSettlementTest is Test {
    RFQSettlement public settlement;
    MockERC20 public baseToken;
    MockERC20 public quoteToken;

    address public creator;
    address public acceptor;

    uint256 constant BASE_AMOUNT = 100 * 10 ** 18;
    uint256 constant QUOTE_AMOUNT = 200 * 10 ** 18;

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

    /**
     * Test 1: Successful atomic swap on same chain
     * Critical behavior: Verify that tokens are transferred correctly between parties
     */
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

    /**
     * Test 2: Revert when creator has insufficient base token balance
     * Critical behavior: Prevent swaps when creator cannot fulfill their obligation
     */
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

    /**
     * Test 3: Revert when acceptor has insufficient quote token balance
     * Critical behavior: Prevent swaps when acceptor cannot fulfill their obligation
     */
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

    /**
     * Test 4: Revert when base amount is zero
     * Critical behavior: Prevent invalid swaps with zero amounts
     */
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

    /**
     * Test 5: Revert when quote amount is zero
     * Critical behavior: Prevent invalid swaps with zero amounts
     */
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

    /**
     * Test 6: Revert when token addresses are zero address
     * Critical behavior: Prevent invalid swaps with invalid token addresses
     */
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
}
