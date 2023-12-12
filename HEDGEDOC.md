# Hedge Smart Contract Technical Documentation

## Overview

Hedge is a smart contract developed by Nectar Development Co., implementing a one-click delta-neutral strategy. The primary purpose of Hedge is to manage a delta-neutral position using collateralized assets and borrowed assets through the Fraxlend protocol. This documentation provides a technical overview of the contract's structure, state variables, events, modifiers, and functions.

### Contract Information

- **Name:** Hedge
- **License:** MIT
- **Solidity Version:** >=0.8.20
- **Dependencies:**
  - OpenZeppelin Contracts v4.3.0 (IERC20, IERC20Metadata, ReentrancyGuard, SafeERC20, SafeCast, Strings)

### Contact Information

For inquiries about the Hedge smart contract, you can reach out to Nectar Development Co.

## State Variables

### User-Level Accounting

```solidity
struct UserData {
    uint256 sfrxEthAmount;   // Total sfrxEth deposited by the user
    uint256 depositShares;   // Value of the user's hedge position
}

mapping(address => UserData) public userData; 
```

### Contract-Level Accounting

```solidity
uint256 public collateralBalance;     // Hedge's collateral balance on Fraxlend
uint256 public totalValueLocked;      // Hedge's total value locked
uint256 public totalBorrowed;         // Hedge's total borrowed amount
uint256 public hedgeLtv;              // Hedge's loan-to-value ratio
uint256 public collateralValue;       // Value of Hedge's collateral balance converted to dollars
uint256 public targetBorrowAmount;    // Target borrow amount for balancing Hedge
address public immutable hedge;       // Hedge's address
address public immutable positionManager;  // Nectar Position Manager address
address public immutable balancerAddress;  // Balancer / Chron Job address
IFraxlendPair public fraxlend;        // Fraxlend interface
IAxelarRelay public axelarRelay;      // Position Manager Interface
IERC20 public sfrxEth;                // sfrxETH token interface
IERC20 public frax;                   // Frax token interface
address public sfrxEthToken;          // Address of the deposit token
address public fraxToken;             // Address of the borrowed token
address public fraxlendPair;          // Address of Fraxlend Pair
address public axelarRelayAddress;    // Address of Nectar cross-chain collateral manager
string public destinationChain;       // Destination chain for Axelar
string public destinationAddress;     // Position Manager address to string for Axelar Gateway
string public symbol;                 // Loan token symbol
```

## Events

### Deposit

Emitted when a user deposits sfrxEth into the Hedge smart contract.

```solidity
event Deposit(address indexed user, uint256 sfrxEthAmount, uint256 depositShares, uint256 collateralBalance, uint256 totalValueLocked);
```

### Withdrawal

Emitted when a user withdraws sfrxEth from the Hedge smart contract.

```solidity
event Withdrawal(address indexed user, uint256 sfrxEthAmount, uint256 depositShares, uint256 collateralBalance, totalValueLocked);
```

### AssetRepayed

Emitted when Frax is repayed to Hedge's debt balance on Fraxlend.

```solidity
event AssetRepayed(uint256 totalBorrowed);
```

### HedgeBalanced

Emitted when Hedge's position is balanced.

```solidity
event HedgeBalanced(uint256 totalBorrowed);
```

## Modifiers

### onlyAxelarRelay

Ensures that the caller is the Axelar Relay contract.

```solidity
modifier onlyAxelarRelay {
    require(msg.sender == axelarRelayAddress, "Axelar Relay contract only");
    _;
}
```

### onlyBalancer

Ensures that the caller is Balancer bot

```solidity
modifier onlyBalancer {
    require(msg.sender == balancerAddress, "Balancer contract only");
    _;
}
```

## Constructor

The constructor initializes the Hedge smart contract with the provided parameters, setting various addresses and initializing state variables.

```solidity
constructor(
    address _fraxlendPair,
    address _fraxToken,
    address _sfrxEthToken,
    address _axelarRelayAddress,
    address _positionManager,
    address _balancerAddress,
    string memory _destinationChain
)
```

## Public Functions

### deposit

Allows users to deposit sfrxEth into the Hedge smart contract, updating their positions and triggering the internal _balanceHedge function.

```solidity
function deposit(uint256 _amount) external nonReentrant
```
### withdraw

Allows users to withdraw sfrxEth from the Hedge smart contract, updating their positions and triggering the internal _balanceHedge function.

```solidity
function withdraw(uint256 _amount) external nonReentrant
```
## Internal Functions

### _balanceHedge

Internal function used to maintain the delta-neutral position of the Hedge by adjusting collateral and short positions based on the loan-to-value ratio.

```solidity
function _balanceHedge() public onlyBalancer
```
### _deposit

Internal function that handles the logic for user deposits, updating user data, collateral, total value locked, and triggering the internal _balanceHedge function.

### _repayAsset

Internal function used to repay assets to Fraxlend from Hedge, updating the total borrowed amount.

```solidity
function _repayAsset(uint256 _amount) external onlyAxelarRelay

```
### _addCollateral

Internal function used to add collateral to the Hedge's Fraxlend account, updating the collateral balance.

```solidity
function _addCollateral(uint256 _amount) external onlyAxelarRelay
```
## Read-Only Functions

### getCollateralValue

Returns the dollar value of Hedge's collateral balance in Fraxlend.

```solidity
function getCollateralValue() public view returns (uint256)
```
### getSfrxEthBalance

Returns the available sfrxEth balance for a given user account.

```solidity
function getSfrxEthBalance(address _account) public view returns (uint256)
```

## Conclusion 

The Hedge smart contract implements a delta-neutral strategy, managing collateralized and borrowed assets through the Fraxlend protocol. Users can deposit and withdraw sfrxEth, while the contract internally balances its position through the _balanceHedge function. The contract interacts with the Axelar Relay and Fraxlend protocols for cross-chain functionality and lending operations, respectively. Developers and users interested in interacting with the Hedge smart contract should refer to this documentation for a comprehensive understanding of its structure and functionality.



