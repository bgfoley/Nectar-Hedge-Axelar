# Nectar-Hedge-Axelar

## Overview

Nectar-Hedge-Axelar is a stripped-down precursor to Hedge's Minimum Viable Product (MVP), designed to leverage Axelar for cross-chain execution. This project is configured to be integrated with various perp dexs into the Hedge platform. 

## Dev Dependencies

The project utilizes the following packages as development dependencies:
- [Fraxlend](https://github.com/FraxFinance/fraxlend)
- [Axelar](https://github.com/axelarnetwork/axelar-gmp-sdk-solidity)

## Getting Started

To get started with the project, follow these steps:

1. Clone this repository to your local machine.
2. Install Node.js if you haven't already.
3. Open your terminal and navigate to the project's root directory.
4. Run the following command to install project dependencies:

   ```bash
   npm install

## Project Details
Perp DEX Integration: This repository serves as a foundation for integrating various decentralized exchanges. The intention is to expand this project to include Synthetix (Optimism), GMXv2 (Arbitrum), and other perp dex platforms of interest.

Order Execution Logic: For each perp dex integration, the order execution logic will need to be implemented differently, tailored to the specific platform. However, the project will continue to utilize Axelar for streamlined cross-chain communication, enabling consistency in parameter passing.

Future Integration: The long-term vision includes the possibility of swapping out Fraxlend components with AAVE, allowing the integration of alternate yield-bearing tokens such as StETH and rETH as collateral.
