# gas-optimized-solidity-patterns

A compact repo that demonstrates practical gas-saving patterns for Solidity developers.

## Patterns included
- calldata vs memory strategies
- Yul memcpy
- unchecked arithmetic
- storage packing / bitpacking
- immutable / constant usage
- optimized events and batch transfers
- minimal loops + short-circuiting

## Quickstart
1. Create a new repo and paste these files:
   - contracts/GasPatterns.sol
   - test/gasPatterns.test.js
   - package.json
   - hardhat.config.ts
2. Install:
3. Compile:
4. Run tests:

## Notes
- Use a linter and run static analyzers before production use.
- Patterns shown are educational — measure gas with `hardhat test` and `gas-reporter` as needed.

