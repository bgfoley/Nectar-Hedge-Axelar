# Nectar-Hedge-Axelar

## Overview

Nectar-Hedge-Axelar is a stripped-down precursor to Hedge's Minimum Viable Product (MVP), designed to leverage Axelar for cross-chain execution. This project is configured to be integrated with various perp dexs into the Hedge platform. 

## Dev Dependencies

The project utilizes the following packages:
- [Fraxlend](https://github.com/FraxFinance/fraxlend)
- [Axelar GMP sdk](https://github.com/axelarnetwork/axelar-gmp-sdk-solidity)

## Getting Started

To get started with the project, follow these steps:

1. Clone this repo
2. Install Node.js if you haven't already.
5. Run npm install to install dependencies

## Project Details

LSD Integration: Currently configured for sfrxEth and Frax, for use with Fraxlend. In the next iteration, we could move token specific variables into a data struct that will allow us to easily integrate alt LSDs into the Hedge product 

Perp DEX Integration: This repo can serve as a foundation for integrate with any perp dex. The intention is to expand this project to include Synthetix (Optimism), GMXv2 (Arbitrum), and other platforms interest.

Order Execution Logic: For each perp dex integration, the order execution logic will need to be implemented differently, tailored to the specific platform. We'll need to create interfaces for each platform that can receive the same arguments through our Axelar configuration. Should only need totalEthCollateral on lending platform, and call to either add or remove collateral from perp dex.

Future: The long-term vision includes the possibility of swapping out Fraxlend components with AAVE, allowing the integration of alternate yield-bearing tokens such as StETH and rETH as collateral. We can acheive this by moving our Hedge state variables into data structures that allows us to incorporate multiple configurations

## Hedge Flow Chart
![Flow Chart](./NectarContractFlowChart.drawio.png)

