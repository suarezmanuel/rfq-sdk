# [TBD] - Decentralized P2P Cross-Chain Trading Platform

A fully decentralized platform for peer-to-peer Request for Quote (RFQ) trading with cross-chain settlement capabilities.

## Overview

[TBD] enables traders to create, browse, and execute token swaps without centralized intermediaries or high on-chain storage costs. By leveraging Arkiv Network for RFQ storage and querying, combined with Wormhole for cross-chain settlement, the platform delivers true decentralized P2P trading across multiple blockchains.

### Key Features

- **Decentralized RFQ Management**: Store and query RFQs using Arkiv Network.
- **Complex Querying**: Filter and sort RFQs by token pair, chain, price range, expiration, and creator
- **Same-Chain Atomic Swaps**: Execute trades on a single blockchain with atomic settlement
- **Cross-Chain Trading**: Trade tokens across different blockchains using Wormhole messaging
- **Real-Time Updates**: Subscribe to RFQ events with live updates (no polling required)
- **Multi-Wallet Support**: Connect with MetaMask or WalletConnect (Reown)
- **Zero Backend**: Fully client-side application with no centralized servers

## Tech Stack

**Smart Contracts:**

- Solidity 0.8.24
- Foundry (testing & deployment)
- OpenZeppelin (ERC20 utilities)
- Wormhole SDK (cross-chain messaging)

**RFQ SDK:**

- TypeScript
- Arkiv SDK (decentralized storage)
- ethers.js v6 (blockchain interactions)
- Dual ESM + CommonJS build

**Frontend:**

- React 18+ with Vite
- TypeScript
- wagmi + viem (Web3 interactions)
- RainbowKit (wallet connection)
- Tailwind CSS (styling)

**Testnets:**

- Sepolia (Ethereum testnet)
- Base Sepolia (Base testnet)

## Links

- **Deployed Demo**: [Coming Soon]
- **Demo Video**: [Coming Soon]
- **Arkiv Network**: <https://arkiv.network/docs>
- **Wormhole**: <https://docs.wormhole.com>
- **Contract Addresses**: See `.env.example` for testnet deployments

## License

TBD

---

**Built with ♥️ for Tierra De Builders - Ethereum Argentina**
