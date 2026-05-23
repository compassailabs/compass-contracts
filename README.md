# Compass AI Contracts

Smart contracts for **Compass AI**, a multi-chain USDC yield aggregator built on
Circle Gateway and ERC-4337 account abstraction.

Every user owns a Diamond (EIP-2535) at the same address on every chain.
The Diamond holds USDC, bridges through Circle Gateway, and supplies to
AAVE under a scoped session key.

## Repository Structure

```
src/
├── CompassAccount.sol           // Diamond proxy
├── CompassAccountFactory.sol    // CREATE2 factory
├── InitCompass.sol              // Diamond initializer
├── CompassPaymaster.sol         // USDC → ETH gas paymaster
├── CompassCreate2.sol           // Deterministic deployer
├── facets/                      // Account, Security, Gateway, Aave, Upgrade
├── interfaces/
└── libraries/

script/
├── Deploy.s.sol                 // Core deployment
└── DeployPaymaster.s.sol        // Paymaster deployment

test/
```

## Local Development

```bash
forge install
forge build
forge test
```

## Deployment

Both scripts deploy via `CompassCreate2` so addresses are identical
across chains for the same broadcaster and salt.

```bash
# Core (run on every supported chain)
forge script script/Deploy.s.sol --rpc-url <RPC> --private-key <KEY> --broadcast

# Paymaster (Arbitrum only — set CREATE2_DEPLOYER first)
forge script script/DeployPaymaster.s.sol --rpc-url <RPC> --private-key <KEY> --broadcast
```

To redeploy, bump the `SALT` in both scripts.

## License

MIT — see [LICENSE](./LICENSE).
