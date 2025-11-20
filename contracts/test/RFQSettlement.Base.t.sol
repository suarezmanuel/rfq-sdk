// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RFQSettlement.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockWormholeRelayer.sol";

/**
 * @title RFQSettlementBaseTest
 * @dev Base test contract with common setup for all RFQSettlement tests
 */
abstract contract RFQSettlementBaseTest is Test {
    RFQSettlement public settlement;
    MockERC20 public baseToken;
    MockERC20 public quoteToken;
    MockWormholeRelayer public wormholeRelayer;

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

    function setUp() public virtual {
        // Deploy mock Wormhole relayer
        wormholeRelayer = new MockWormholeRelayer();

        // Deploy settlement contract with Wormhole relayer
        settlement = new RFQSettlement(address(wormholeRelayer));

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

    // Receive function to accept ETH refunds
    receive() external payable {}
}
