# Contracts

# Hedge

## Overview

Hedge is a smart contract developed by Nectar Development Co., implementing a one-click delta-neutral strategy. The primary purpose of Hedge is to manage a delta-neutral position using collateralized yield bearing assets as a long position, and borrowed assets through the Fraxlend protocol to collateralize short positions on perpetuals dex. This documentation provides a technical overview of the contract's structure, state variables, events, modifiers, and functions.

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

This is a WIP. User level accounting will be tokenized for production. Instead of writing these balances to storage, we'll mint erc721s  (or 20s) for each user position that will include the epoch of their deposit. When shorts are placed, state of epochs will be updated and necUSD will be mintable by user.

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

Here's how it works:

When a user makes a deposit or withdrawal, the contract runs checks to make sure its a valid deposit/withdrawal amount, then updates the state variables for user accounting and contract level accounting (TVL and Collateral Value).

Once the state variables have been updated, the contract run the internal balance Hedge function which runs through its own checks to ensure that it is properly managing and balancing liquidity for the entire system based on the updated state variables.

Here are the checks balanceHedge runs through to make sure the contract level accounting remains balanced:

1) Is the Hedge contract solvent? i.e. Is there enough sfrxEth in Fraxlend to cover TVL (combined value of user deposits)?
    If collateralValue >= totalValueLocked
        Hedge is solvent - place shorts based on new position size (collateral balance should be equal to short position size)
    If collateralValue < totalValueLocked
        Hedge is insolvent and needs more sfrxEth for Fraxlend - sell shorts and swap profits for sfrxEth, add to Fraxlend
2) Is the loan size correct?
    If totalBorrowed >= totalValueLocked * (1/3)
        Hedge needs to remove collateral from the perp side and payback Frax
    If totalBorrowed < totalValueLocked * (1/3)
        Hedge can borrow more Frax and add collateral to the perp side

Based on these checks one of the following commands will be sent to the Position Manager along with the proper amounts:
    addCollateralPlaceShort
    addCollateralSellShort
    removeCollateralPlaceShort
    removeCollateralSellShort

These methods are combined as seen above to suit our Axelar Relay contract for cross chain GMP. If we configure the entire
system on one chain, we'll be able to call each method on it's own from Hedge to the Position Manager contract, and the Axelar 
Relay will be deprecated.

```solidity
function _balanceHedge() public onlyBalancer
```
### _deposit

Internal function that handles the logic for user deposits, updating user data, collateral, total value locked, and triggering the internal _balanceHedge function. Deposit function is split between internal and external to limit reentrancy attack vectors.

### _repayAsset

Internal function used to repay assets to Fraxlend from Hedge, updating the total borrowed amount. This will be called by the Position Manager via cross chain messaging (if protocol is split between two blockchains), or directly if on the same network, after the Position Manager has received a call from Hedge to remove collateral from the perp side. 

```solidity
function _repayAsset(uint256 _amount) external onlyAxelarRelay

```
### _addCollateral

Internal function used to add collateral to the Hedge's Fraxlend account, updating the collateral balance. This will be called by the Position Manager via cross chain messaging (if protocol is split between two blockchains), or directly if on the same network, after the Position Manager has received a call from Hedge to sell short on the perp side and add collateral to the long position.

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

# AxelarRelay

## Overview

AxelarRelay is a smart contract developed by Nectar Development Co., that facilitates cross chain message passing between Ethereum Mainnet and any EVM based layer 2 (Op or Arbitrum). The primary purpose is to send liquidity from the long position on Mainnet, to the short position on the perp dex (layer 2). 

### Contract Information

- **Name:** AxelarRelay
- **License:** MIT
- **Solidity Version:** >=0.8.20
- **Dependencies:**
  - OpenZeppelin Contracts v4.3.0 (IERC20, AxelarExecutable, IAxelarGasService, AxelarExpressExecutable, IAxelarGateway, IPositionManager, IHedge)

### Contact Information

For inquiries about the AxelarRelay smart contract, you can reach out to Nectar Development Co.

## State Variables

### Gas Service Interface

Interface for the Axelar gas service, providing gas-related functionality.

```solidity
IAxelarGasService public immutable gasService;
Interface for the Axelar gas service, providing gas-related functionality.
```

### Position Manager Interface

Interface for the Position Manager contract, allowing interaction with position-related functions.

```solidity
IPositionManager public immutable positionManager;
```

### Hedge Interface

Interface for the Hedge contract, facilitating interaction with Hedge-specific functions.

```solidity
IHedge public hedgeInterface;
```

### Hedge and Position Manager Addresses

Addresses of the Hedge and Position Manager contracts.

```solidity
address public immutable hedge;
address public immutable positionManagerAddress;
```

## Modifiers

### Only Hedge Modifier

Ensures that a function can only be called by the Hedge contract.

```solidity
modifier onlyHedge {
    require(msg.sender == hedge, "Hedge only");
    _;
}
```

### Only Position Manager Modifier

Ensures that a function can only be called by the Position Manager contract.

```solidity
modifier onlyPositionManager {
    require(msg.sender == positionManagerAddress, "Position Manager only");
    _;
}
```

## Functions

### Constructor

Initializes the AxelarRelay contract with required parameters, including the Axelar Gateway, gas service, Hedge, and Position Manager addresses.

```solidity
constructor(
    address gateway_,
    address gasReceiver_,
    address _hedge,
    address _positionManagerAddress
) AxelarExpressExecutable(gateway_) {
    // constructor logic
}
```

## Write Functions

### Add Collateral and Place Short

Allows the Hedge contract to add collateral and place a short position on another chain using the Axelar Express Executable.

```solidity
function addCollateralPlaceShort(
    string memory destinationChain,
    string memory destinationAddress,
    uint256 collateralBalance,
    string memory symbol,
    uint256 toTarget
) external payable onlyHedge {
    // function logic
}
```

### Add Collateral and Sell Short

Allows the Hedge contract to add collateral and sell a short position on another chain using the Axelar Express Executable.

```solidity
function addCollateralSellShort(
    string memory destinationChain,
    string memory destinationAddress,
    uint256 collateralNeeded,
    string memory symbol,
    uint256 toTarget
) external payable onlyHedge {
    // function logic
}
```

### Remove Collateral and Place Short

Allows the Hedge contract to remove collateral and adjust a short position on another chain using the Axelar Express Executable.

```solidity
function removeCollateralPlaceShort(
    string memory destinationChain,
    string memory destinationAddress,
    uint256 collateralBalance,
    string memory symbol,
    uint256 toTarget
) external payable onlyHedge {
    // function logic
}
```

### Remove Collateral and Sell Short

Allows the Hedge contract to remove collateral and sell a short position on another chain using the Axelar Express Executable.

```solidity
function removeCollateralSellShort(
    string memory destinationChain,
    string memory destinationAddress,
    uint256 collateralNeeded,
    uint256 toTarget
) external payable onlyHedge {
    // function logic
}
```

## Internal Functions

### Execute With Token

Internal function override to execute transactions involving x-chain transfers with a specific token.

```solidity
function _executeWithToken(
    string calldata,
    string calldata,
    bytes calldata payload,
    string calldata tokenSymbol,
    uint256 amount
) internal override {
    // function logic
}
```

### Execute

Internal function override to execute x-chain contract calls without token transfers.

```solidity
function _execute(
    string calldata,
    string calldata,
    bytes calldata payload
) internal override {
    // function logic
}
```
