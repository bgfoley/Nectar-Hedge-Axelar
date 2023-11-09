//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// Nectar Axelar Interface - handles perps
import { IPositionManager } from 'contracts/PositionManager.sol';
import { IFraxlendPair } from 'contracts/interfaces/Fraxlend/IFraxlendPair.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { IERC20Metadata } from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Hedge is ReentrancyGuard{
    using AddressToString for address;
    using SafeMath for uint256;
    
    // User Accounting
    /// Store Eth balance & value of Hedge position 
    struct UserData {
    uint256 ethAmount;  // The total deposited or withdrawn amount in the user's account
    uint256 value;      // The value of their hedge position
    }
   
    mapping(address => UserData) userInfo; // Store user addresses against user balance data

    address payable public hedge;
    // Fraxlend interface
    IFraxlendPair public fraxlend; 
    // Position Manager Interface
    IPositionManager public positionManager;
    // sfrxETH token interface
    IERC20 public sfrxEth;
    // Frax token interface
    IERC20 public frax;
    // address of the deposit token
    address public sfrxEthToken;
    // address of borrowed token
    address public fraxToken;
    // address of Fraxlend Pair
    address public fraxlendPair;
    // address of Nectar cross chain collateral manager
    address public positionManagerAddress;
    // Data for Axelar cross chain GMP
    string public destinationChain;
    // Position Manager address to string
    string public destinationAddress;
    // loan token symbol
    string internal symbol;
    // Hedge LTV
    uint256 public hedgeLtv;
    // Fraxlend collateral balance
    uint256 public collateralBalance;

    // Events    
    event Deposit(address indexed user, uint256 ethAmount, uint256 value);
    event Withdrawal(address indexed user, uint256 ethAmount, uint256 value);
    // Modifiers
    /*
    modifier onlyPositionManager {
        require(msg.sender == positionManagerAddress, "Postion manager contract only");
        _;
    }
    */

    constructor(
        address _fraxlendPair,           // 0x78bB3aEC3d855431bd9289fD98dA13F9ebB7ef15
        address _fraxToken,              // 0x853d955aCEf822Db058eb8505911ED77F175b99e
        address _sfrxEthToken,           // 0xac3E018457B222d93114458476f3E3416Abbe38F
        address _positionManagerAddress, // 
        string  _destinationChain)       // Use "Optimism" for destinationChain  
        {
        hedge = payable(msg.sender);
        positionManager = IPositionManager(positionManagerAddress);
        fraxlendPair = _fraxlendPair;
        fraxlend = IFraxlendPair(fraxlendPair); 
        fraxToken = _fraxToken;
        sfrxEthToken = _sfrxEthToken;
        frax = IERC20(fraxToken);
        sfrxEth = IERC20(sfrxEthToken);
        destinationChain = _destinationChain;
        positionManagerAddress = _positionManagerAddress;
        destinationAddress = AddressToString(positionManagerAddress);
        symbol = getSymbol(_fraxToken);
        collateralBalance = fraxlend.userCollateralBalance(hedge);
        hedgeLtv = getHedgeLtv();
    }

    // Get the loan health of Hedge's fraxlend account
    function getHedgeLtv() public view returns (uint256) {
        uint256 exchangeRate = fraxlend.exchangeRateInfo.highExchangeRate;
        uint256 borrowAmount = fraxlend.toBorrowAmount.userBorrowShares(hedge);
        uint256 hedgeLTV = borrowAmount
            .mul(exchangeRate
            .div(BigInt(1e18))
            .mul(1e5)
            .div(collateralBalance);
        return hedgeLtv;
    }



    // Deposit
    // Retrieve the user's existing transaction data
    // transfer yield bearing tokens from user to contract
    // Approve the fraxlend pair for transfer
    // Calculate what Hedge's sfrxEth balance will be after adding collatteral
    // add new collateral and pass account address for Hedge
    // Internal function Balance Hedge takes newCollateralBalance as argument
    // Use the exchange rate to get the value of deposit
    // Update the amount by adding the deposit amount
    // Update the value of user's position
    // emit deposit event
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Deposit amount must be greater than zero");
        UserData storage user = userInfo[msg.sender];
        sfrxEth.transferFrom(msg.sender, hedge, amount);
        sfrxEth.approve(fraxlendPair, amount);
        uint256 newCollateralBalance = fraxlend.getUserSnapshot.ColateralBalance(hedge).add(amount);
        fraxlend.addCollateral(amount, hedge);
        balanceHedge(newCollateralBalance);
        uint256 value = fraxlend.exchangeRateInfo.highExchangeRate.mul(amount);
        user.amount += amount;
        user.value += value;
        emit Deposit(msg.sender, ethAmount, value);
    }
    // Withdraw 
    // Retrieve the user's existing transaction data
    // Check that user has sufficient sfrxEth balance
    // Calculate what Hedge's sfrxEth balance will be after removing collateral
    // Internal function Balance Hedge takes newCollateralBalance as argument
    // Use the exchange rate to get the value of the withdrawal
    // Update user's ethAmount
    // Update user's hedge value
    // Emit Withdrawal event
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Withdraw amount must be greater than zero");
        UserData storage user = userInfo[msg.sender];
        require(user.ethAmount >= amount, "Insufficient balance for withdrawal");
        uint256 newCollateralBalance = fraxlend.getUserSnapshot.ColateralBalance(hedge).sub(amount);
        balanceHedge();
        uint256 value = fraxlend.exchangeRateInfo.highExchangeRate.mul(amount);
        user.ethAmount -= amount;
        user.value -= value;
        emit Withdrawal(msg.sender, amount, value);
    }

    /* This function maintains the balanced state of the Hedge -- check for 
    a loan to Value of 1:3 in Fraxlend, thens calls addCollateralPlaceShort 
    or removeCollateral to make up the difference on the perp dex side
    It is called by deposit and withdraw, or can be called
    by anyone willing to pay gas */
    // get number of outstanding borrowShares
    // Convert borrowShares to borrowAmount, (include arguments Round up = true, previewInterest, true
    // Get the exchange rate from the fraxlend pair
    // Check if the function is called internally or externally
    // If so, use the newCollateralBalance
    // Calculate LTV
    // Else, use the collateralBalance from fraxlendPair
    // Get LTV
    // Get the correct loan size frax needed to acheive - 1:3 LTV
    // Solve for amount of frax to borrow or repay to fraxlend
    // If > 1:3 remove collateral from perp account
    // If < 1:3 borrow from fraxlend and add collateral to perp and place short
    function balanceHedge() public nonReentrant {
        uint256 borrowShares = fraxlend.userBorrowShares(hedge);
        uint256 borrowAmount = fraxlend.toBorrowAmount(borrowShares, true, true);
        uint256 exchangeRate = fraxlend.exchangeRateInfo.highExchangeRate;
        uint256 _collateralBalance;
        if (msg.sender == hedge) {
        _collateralBalance = newCollateralBalance; 
        uint256 _hedgeLtv = borrowAmount
            .mul(exchangeRate
            .div(BigInt(1e18))
            .mul(1e5)
            .div(_collateralBalance);    
        } 
        else 
        {
        _collateralBalance = collateralBalance;
        _hedgeLtv = getHedgeLtv();
        }
        uint256 targetBorrowAmount = _collateralBalance
            .mul(BigInt(1e18))
            .mul(_hedgeLtv)
            .div(exchangeRate)
            .div(1e5);
        if (_hedgeLtv > (1 * 1e5) / 3) {
        uint256 toTarget = targetBorrowAmount
        .sub((1 * 1e5) / 3);
        positionManager.removeCollateral(
            destinationChain, 
            destinationAddress, 
            _collateralBalance,  
            toTarget);  
        }
        else 
        {
        uint256 toTarget = ((1 * 1e5) / 3)
        .sub(targetBorrowAmount);
        fraxlend.borrowAsset(toTarget);
        frax.approve(positionManager, toTarget);
        positionManager.addCollateralPlaceShort(
            destinationChain, 
            destinationAddress,
            collateralBalance, 
            toTarget);
        }
    }   
}
