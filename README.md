# YieldFarm

## Overview

This project is a yield farming contract built with Solidity. It allows users to stake ERC-20 tokens to earn rewards, with support for boosting rewards using NFTs and a referral system. The contract also includes various features like emergency withdrawal, pausing, and unpausing the contract.

## Contracts

### 1. YieldFarm

This contract is the main yield farming contract where users can stake tokens to earn rewards. It supports multiple staking pools, each with its own staking and reward tokens, reward rates, and lock durations.

### 2. YieldFarmTest

A contract designed to test the functionalities of the YieldFarm contract. It includes the `TestToken` and `TestNFT` contracts for testing purposes.

#### TestToken

A simple ERC-20 token used for testing purposes. It can be used as both staking and reward tokens in the yield farming contract.

#### TestNFT

A simple ERC-721 token used for testing purposes. Holding these NFTs can boost the rewards earned from staking.

## Deployment

This project was fully developed and tested using the Remix IDE.

## Key Functionalities

### Staking

Users can stake ERC-20 tokens in the specified pool to earn rewards. The staked tokens are locked for a specified duration.

### Unstaking

After the lock duration, users can unstake their tokens from the specified pool.

### Claiming Rewards

Users can claim their accumulated rewards from the specified pool.

### Emergency Withdrawal

Users can withdraw their staked tokens without claiming rewards in case of emergencies.

### Referral System

Users can set a referrer to earn additional rewards for both the referrer and the referee.

### Pausing/Unpausing

The contract owner can pause and unpause the contract to prevent any actions during emergencies.

## Contract Interfaces

### YieldFarm

- `initialize()`
- `addPool()`
- `stake()`
- `unstake()`
- `claimReward()`
- `emergencyWithdraw()`
- `setReferrer()`
- `setRewardRate()`
- `setLockDuration()`
- `setNftBoostRate()`
- `distributeGovernanceTokens()`
- `pause()`
- `unpause()`

### YieldFarmTest

- `constructor()`
- `testStake()`
- `testUnstake()`
- `testClaimReward()`
- `testEmergencyWithdraw()`
- `testPauseAndUnpause()`
- `testReferralSystem()`

#### TestToken

- `constructor(string memory name, string memory symbol, uint256 initialSupply)`

#### TestNFT

- `constructor(string memory name, string memory symbol)`
- `mint(address to)`

## Notes

- This project utilizes OpenZeppelin's upgradeable contracts for enhanced security and upgradeability.
- The contract code includes comprehensive comments and is designed to be easily understandable and maintainable.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
