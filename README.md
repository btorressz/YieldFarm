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
