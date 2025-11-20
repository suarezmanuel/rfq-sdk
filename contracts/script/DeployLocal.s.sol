// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/RFQSettlement.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice Simple ERC20 token for testing
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18); // Mint 1M tokens
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title DeployLocal
 * @notice Deployment script for local testing of quote acceptance
 */
contract DeployLocal is Script {
    RFQSettlement public settlement;
    MockERC20 public usdc;
    MockERC20 public usdt;
    MockERC20 public dai;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying with address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock ERC20 tokens
        console.log("\n=== Deploying Mock Tokens ===");
        usdc = new MockERC20("USD Coin", "USDC");
        console.log("USDC deployed at:", address(usdc));

        usdt = new MockERC20("Tether USD", "USDT");
        console.log("USDT deployed at:", address(usdt));

        dai = new MockERC20("Dai Stablecoin", "DAI");
        console.log("DAI deployed at:", address(dai));

        // Deploy RFQSettlement contract
        console.log("\n=== Deploying RFQSettlement ===");
        settlement = new RFQSettlement();
        console.log("RFQSettlement deployed at:", address(settlement));

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("RFQSettlement:", address(settlement));
        console.log("USDC:", address(usdc));
        console.log("USDT:", address(usdt));
        console.log("DAI:", address(dai));

        // Save deployment addresses to file
        string memory deploymentInfo = string(abi.encodePacked(
            "RFQSettlement=", vm.toString(address(settlement)), "\n",
            "USDC=", vm.toString(address(usdc)), "\n",
            "USDT=", vm.toString(address(usdt)), "\n",
            "DAI=", vm.toString(address(dai)), "\n"
        ));
        vm.writeFile("deployments/local.txt", deploymentInfo);
        console.log("\nDeployment addresses saved to deployments/local.txt");
    }
}
