# Nectar-Hedge-Axelar

## Overview

Nectar-Hedge-Axelar is a precursor to Hedge's Minimum Viable Product (MVP), designed to leverage Axelar for cross-chain execution. This project is configured to be integrated with various perp dexs into the Hedge platform. 

## Dev Dependencies

The project utilizes the following packages:
- [Fraxlend](https://github.com/FraxFinance/fraxlend)
- [Axelar GMP sdk](https://github.com/axelarnetwork/axelar-gmp-sdk-solidity)

## Getting Started

To get started, follow these steps:

1. Clone this repo
2. Install Node.js if you haven't already.
5. Run npm install to install dependencies

## Project Details

LSD Integration: Currently configured for sfrxEth and Frax, for use with Fraxlend. In the next iteration, we could move token specific variables into a data struct that will allow us to easily integrate alt LSDs into the Hedge product 

Perp DEX Integration: This repo can serve as a foundation for integrate with any perp dex. The intention is to expand this project to include Synthetix (Optimism), GMXv2 (Arbitrum), and other platforms interest.

Order Execution Logic: For each perp dex integration, the order execution logic will need to be implemented differently, tailored to the specific platform. We'll need to create interfaces for each platform that can receive the same arguments through our Axelar configuration. Should only need totalEthCollateral on lending platform, and call to either add or remove collateral from perp dex.

Future: The long-term vision includes the possibility of swapping out Fraxlend components with AAVE, allowing the integration of alternate yield-bearing tokens such as StETH and rETH as collateral. We can acheive this by moving our Hedge state variables into data structures that allows us to incorporate multiple configurations

## Hedge Flow Chart

![Hedge Flow Chart](NectarContractFlowChart.drawio.png)


# Hedgenomics

## Principle

Hedge automates the process of delta hedging by establishing a delta neutral position for a given collateral token on the user’s behalf. For example, if a user wishes to forgo the volatility risk inherent with an asset like sfrxEth, but still receive the yield inherent with maintaining their sfrxEth position, Hedge allows the user’s asset value to stay flat, while their yield-bearing tokens earn yield.

Delta neutral means neutral to change. With regard to our use case, it means maintaining two equal and opposite positions to neutralize any price change in the underlying asset.

## How it Works

The protocol utilizes a decentralized lending service such as Fraxlend or Aave to establish the “long” position, and a perpetuals dex such as Kwenta, or GMX to establish a short position of equal value. Users’ deposits and the total value locked are measured in dollars and stay flat, via the rebalancing of the hedged position.

## User Level Accounting

When a user deposits sfrxEth, they are issued a number of shares equal to the dollar value of their deposit at the time. For example, if a user deposits one sfrxEth and the price of sfrxEth at the time of deposit is $2000, the user will receive 2000 shares. The value of their shares will remain the same regardless of changes to the price of sfrxEth. When the user closes their position by making a withdrawal, they will receive a quantity of sfrxEth equal to $2000 worth of sfrxEth at the time of withdrawal. If sfrxEth is worth $1900, the user will receive ~1.0526 sfrxEth from Hedge.

## Contract Level Accounting

The Hedge smart contracts maintain the flat value of the protocol's liquidity by adjusting exposure in either direction whenever a user makes a deposit or withdrawal. The TVL is measured in dollars, but the assets in Hedge's custody are sfrxEth and an Eth short of equivalent value.

## Balancing the Hedge

Like any good bush, our Hedge requires maintenance to stay in good shape. The system is designed to preserve the stability of its own delta-neutral position in as few moves as possible.

...

## Glossary

- **TVL** - Total Value Locked
- **Collateral Balance** - Hedge’s total amount of sfrxEth held in Fraxlend as deposit collateral.
- **Collateral Value** - Dollar value of Hedge’s collateral holdings on Fraxlend.
- **Position Size** - The value of the short position on the perp dex... will always be equal to the Collateral Value.
- **Total Borrowed** - The total amount borrowed by Hedge from Fraxlend at any given time.
- **Solvency** - Protocols solvency with regard to sfrxEth collateral available to cover the combined total of users’ positions.
- **Target Borrow Amount** - Appropriate loan size to maintain a balanced Hedge state.

...

