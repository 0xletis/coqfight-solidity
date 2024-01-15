# CoqFightTestnet Smart Contract

## Overview
`CoqFightTestnet` is a smart contract developed for the Avalanche Fuji Testnet. It facilitates a coinflip game using ERC20 tokens (AVAX in tesnet case) for wagering. The contract employs Chainlink's Verifiable Random Function (VRF) to ensure fair and transparent game outcomes.

## Requirements
- An Avalanche Fuji Testnet wallet with sufficient AVAX tokens for testing.

## Contract Functions

### Game Management
- `startGame(uint256 _wager)`: Start a new game with a specified wager amount in ERC20 tokens.
- `joinGame(uint256 _gameId)`: Join an existing game using the game's unique ID.
- `cancelGame(uint256 _gameId)`: Cancel an unjoined game. This function is restricted to the contract owner.
- `getActiveGameIds()`: View all active (uncompleted) game IDs.
- `setMinimumWager(uint256 _newMinimumWager)`: Set a new minimum wager amount. This function is restricted to the contract owner.

### Randomness and Game Completion
- `requestRandomWords()`: Internal function to request randomness from Chainlink VRF.
- `fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords)`: Internal function to receive and process the randomness result.
- `_completeGame(uint256 _gameId, uint256[] memory _randomWords)`: Internal function to determine the game winner and transfer the prize.

### Utility and Administration
- `setCallback(uint32 _callbackGasLimit)`: Set a new callback gas limit for the Chainlink VRF response.
- `getRequestStatus(uint256 _requestId)`: Get the status of a randomness request.

## Interaction with Contract
To interact with this contract, you can use [Remix IDE](https://remix.ethereum.org/) or a script using [Ethers.js](https://docs.ethers.io/v5/). Ensure your wallet is connected to the Avalanche Fuji Testnet and has sufficient AVAX tokens.

## Contract Deployment and Testing
Before deploying the contract, ensure the Chainlink VRF subscription is set up and funded. For testing on the Fuji Testnet, deploy the contract using the Remix IDE or a deployment script.

## Notes
- The contract uses a simplified testnet native token wager for testnet purposes, in the mainnet it will be changed to $COQ wagering
- The contract's current configuration uses the Avalanche Fuji Testnet key hash and VRFCoordinator address.
