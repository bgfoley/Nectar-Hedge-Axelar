//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//////===============================================================//////
//////===============================================================//////
//////          /  |  / / ________________ _______________           //////
//////         /   | / //  __//  _//_  __// __  //  __  //           //////
//////        / /| |/ //  __// /__  / /  / /_/ //  /_/ //            //////
//////_______/ / |   / \___/ \___/ / /  /_/ /_//__/ \_ \\____________//////
//////=================//////////HEDGE///////////====================//////
//////===============================================================//////

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { IERC20Metadata } from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import { ReentrancyGuard } from '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Strings } from '@openzeppelin/contracts/utils/Strings.sol';
//import { IFraxlendPair } from '@fraxfinance/fraxlend/src/contracts/interfaces/IFraxlendPair.sol';
import { IFraxlendPair } from 'contracts/interfaces/IFraxlendPair.sol';
import { IAxelarRelay } from 'contracts/test/AxelarRelay.sol';

/* Hedge is a product created by the geniuses at Nectar Development Co. 
Trust us, sir. This is good. */

/// @notice Hedge is Nectar's one-click strategy that takes ether based LSDs 
/// and establishes a 1/1 delta-neutral hedge between fraxlend and a perp dex
contract Hedge is ReentrancyGuard {
    using Strings for address;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

//////==================//////////////////////////===================//////
                       ////      STATE       ////
//////================//////////////////////////=====================//////   

    // User Accounting
    /// Store Eth balance & value of Hedge position 
    struct UserData {
    uint256 sfrxEthAmount;  // Total sfrxEth deposited by user
    uint256 value;      // The value of their hedge position
    }
 
    // Store user addresses against user balance data
    mapping(address => UserData) public userInfo; 

    address payable public hedge;
    // Fraxlend interface
    IFraxlendPair public fraxlend; 
    // Position Manager Interface
    IAxelarRelay public axelarRelay;
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
    address public axelarRelayAddress;
    // Destination chain for Axelar
    string public destinationChain;
    // Position Manager address to string for Axelar Gateway
    string public destinationAddress;
    // loan token symbol
    string public symbol;
    // Hedge LTV
    uint256 public hedgeLtv;
    // Hedge's collateral balance on fraxlend
    uint256 public collateralBalance;
    // For function balanceHedge
    uint256 public constant desiredHedgeLtv = 333333333333333333;



//////==================//////////////////////////===================//////
                       ////      EVENTS      ////
//////================//////////////////////////=====================//////   
    
    event Deposit(address indexed user, uint256 sfrxEthAmount, uint256 value);
    event Withdrawal(address indexed user, uint256 sfrxEthAmount, uint256 value);
    event AssetRepayed(uint256 indexed amount);
    
//////==================//////////////////////////===================//////
                       ////     MODIFIERS    ////
//////================//////////////////////////=====================//////   

    modifier onlyAxelarRelay {
        require(msg.sender == axelarRelayAddress, "Axelar Relay contract only");
        _;
    }

//////==================//////////////////////////===================//////
                       ////    CONSTRUCTOR   ////
//////================//////////////////////////=====================//////   

    /// @dev - consider adding current constructor params to a data struct 
    /// that contains parameters for variations on Hedge. For example stEth
    /// and rEth, so that all Hedge products are contained in this contract
    /// @param _fraxlendPair for long position
    /// @param _fraxToken the borrowed token
    /// @param _sfrxEthToken the collateral token
    /// @param _axelarRelayAddress, @dev use deployment/await script
    /// @param _destinationChain for use by Axelar
    constructor(
        address _fraxlendPair,       // (Mainnet) 0x78bB3aEC3d855431bd9289fD98dA13F9ebB7ef15
        address _fraxToken,          // (Mainnet) 0x853d955aCEf822Db058eb8505911ED77F175b99e
        address _sfrxEthToken,       // (Mainnet) 0xac3E018457B222d93114458476f3E3416Abbe38F
        address _axelarRelayAddress, // 
        string memory _destinationChain,
        string memory _symbol,
        string memory _destinationAddress)       // Use "Optimism" or "Arbittrum" (string) 
        {
        hedge = payable(msg.sender);
        axelarRelayAddress = _axelarRelayAddress;       
        axelarRelay = IAxelarRelay(axelarRelayAddress);
        fraxlendPair = _fraxlendPair;
        fraxlend = IFraxlendPair(fraxlendPair); 
        fraxToken = _fraxToken;
        sfrxEthToken = _sfrxEthToken;
        frax = IERC20(fraxToken);
        sfrxEth = IERC20(sfrxEthToken);
        destinationChain = _destinationChain;
        destinationAddress = _destinationAddress;
        symbol = _symbol;                           
        collateralBalance = fraxlend.userCollateralBalance(hedge);
        hedgeLtv = getHedgeLtv();
        // Preapprove contracts for transferFrom
//        frax.approve(axelarRelay, type(uint256).max);
//        frax.approve(fraxlendPair, type(uint256).max);
//        sfrxEth.approve(fraxlendPair, type(uint256).max);
    }
       
//////==================//////////////////////////===================//////
                       //////     READ     //////
//////================//////////////////////////=====================//////   

    /// @notice '''getHedgeLtv''' gets the loan health of Hedge's fraxlend account
    /// using getter functions from IFraxlend - used by '''balanceHedge''' function
    /// @dev review & revise math - using highExchange rate to stay on the safe side
    /// but let's explore more accurate options
    /// @return hedge contract's loan to value ratio
    function getHedgeLtv() public view returns (uint256) {
        (,uint224 exchangeRate) = fraxlend.exchangeRateInfo();
        uint256 sfrxEthExchangeRate = uint256(exchangeRate);
        uint256 borrowShares = fraxlend.userBorrowShares(hedge);
        uint256 borrowAmount = fraxlend.toBorrowAmount(borrowShares, true);
        uint256 ltvNumerator = borrowAmount * sfrxEthExchangeRate * 1e5;
        uint256 ltvDenominator = collateralBalance * 1e18;
        uint256 hedgeLTV = ltvNumerator / ltvDenominator;
        return hedgeLTV;
    }
/*
    // Turn address to string for Axelar 
    function addressToString(address _address) external pure returns (string memory) {
        return _address.toString();
    }

    // Get the symbol of a token for Axelar
    function getTokenSymbol(address tokenAddress) external view returns (string memory) {
        // Create an instance of the IERC20Metadata interface
        IERC20Metadata token = IERC20Metadata(tokenAddress);

        // Call the symbol function to retrieve the token symbol
        return token.symbol();
    }    
*/
//////==================//////////////////////////===================//////
                       //////     WRITE    //////
//////================//////////////////////////=====================//////   

    /// @notice the '''deposit''' function takes user's sfrxEth and opens delta-neutral hedge
    /// @param amount of sfrxEth deposit
    /// so @dev consider whether or not we should store this variable
    /// @notice value == the amount available for withdrawal
    // Retrieve the user's existing transaction data
    // transfer yield bearing tokens from user to contract
    // Calculate what Hedge's sfrxEth balance will be after adding collatteral
    // add new collateral and pass account address for Hedge
    // Internal function Balance Hedge is called
    // Use the exchange rate to get the value of deposit
    // Update the amount by adding the deposit amount
    // Update the value of user's position
    // emit deposit event
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Deposit amount must be greater than zero");
        UserData storage user = userInfo[msg.sender];
        sfrxEth.safeTransferFrom(msg.sender, hedge, amount);
        uint256 newCollateralBalance = fraxlend.userCollateralBalance(hedge) + amount;
        fraxlend.addCollateral(amount, hedge);
        _balanceHedge(newCollateralBalance);
        (,uint224 exchangeRate) = fraxlend.exchangeRateInfo();
        uint256 sfrxEthExchangeRate = uint256(exchangeRate);
        uint256 _value = sfrxEthExchangeRate * amount;
        user.sfrxEthAmount += amount;
        user.value += _value;
        emit Deposit(msg.sender, amount, _value);
    }
    /// @notice the '''withdraw''' function returns sfrxEth to the user
    /// @param amount is the amount of sfrxEth
    /// @notice value == the amount available for withdrawal  
    // Check amount is greater than zero
    // Retrieve the user's existing transaction data
    // Check that user has sufficient sfrxEth balance
    // Calculate what Hedge's sfrxEth balance will be after removing collateral
    // Internal function Balance Hedge is called
    // Use the exchange rate to get the value of the withdrawal
    // Remove collateral from Fraxlend, receipient is hedge
    // Update user's sfrxEthAmount
    // Update user's hedge value
    // Emit Withdrawal event
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Withdraw amount must be greater than zero");
        UserData storage user = userInfo[msg.sender];
        require(user.sfrxEthAmount >= amount, "Insufficient balance for withdrawal");
        uint256 newCollateralBalance = fraxlend.userCollateralBalance(hedge) - amount;
        _balanceHedge(newCollateralBalance);
        fraxlend.removeCollateral(amount, hedge);
        sfrxEth.safeTransferFrom(hedge, msg.sender, amount);
        (,uint224 exchangeRate) = fraxlend.exchangeRateInfo();
        uint256 sfrxEthExchangeRate = uint256(exchangeRate);
        uint256 _value = sfrxEthExchangeRate * amount;
        user.sfrxEthAmount -= amount;
        user.value -= _value;
        emit Withdrawal(msg.sender, amount, _value);
    }

    /// @notice the '''_balanceHedge''' function maintains the delta neutral position of the Hedge
    /// by 1) check for a loan to Value of 1:3 in Fraxlend, then 2) call addCollateralPlaceShort 
    /// or removeCollateral to make up the difference on the perp dex side
    /// It is called internally by deposit and withdraw, or can be called
    /// externally by anyone willing to pay gas -- 
    /// @dev maybe a chron bot to trigger this every 15 min or so
    /// @param _collateralBalance is Hedge's fraxlend account sfrxEth balance 
    // Get number of outstanding borrowShares
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

    function _balanceHedge(uint256 _collateralBalance) internal {
        (,uint224 exchangeRate) = fraxlend.exchangeRateInfo();
        uint256 sfrxEthExchangeRate = uint256(exchangeRate);
        
        uint256 borrowShares = fraxlend.userBorrowShares(hedge);
        uint256 borrowAmount = fraxlend.toBorrowAmount(borrowShares, true);
    
        // Calculate _hedgeLtv
        uint256 ltvNumerator = borrowAmount * 1e5;
        uint256 ltvDenominator = ltvNumerator / 1e18;
        uint256 _hedgeLtv = ltvDenominator * 1e5 / _collateralBalance;

        // Calculate targetBorrowAmount
        uint256 targetBorrowNumerator = _collateralBalance * 1e18;
        uint256 targetBorrowDenominator = targetBorrowNumerator * _hedgeLtv;
        uint256 targetBorrowAmount = targetBorrowDenominator / sfrxEthExchangeRate / 1e5;

        if (_hedgeLtv > desiredHedgeLtv) {
            uint256 toTarget = targetBorrowAmount - desiredHedgeLtv;
            axelarRelay.removeCollateral(
                destinationChain,
                destinationAddress,
                _collateralBalance,
                toTarget
            );
        } 
        else 
            {
            uint256 toTarget = desiredHedgeLtv - targetBorrowAmount;
            fraxlend.borrowAsset(toTarget, _collateralBalance, hedge);
            axelarRelay.addCollateralPlaceShort(
                destinationChain,
                destinationAddress,
                _collateralBalance,
                symbol,
                toTarget
            );
        }
    }

    /// @notice '''balanceHedge''' is an external function to trigger _balanceHedge
    /// @dev calls _balanceHedge and passes current collateralBalance as argument
    function balanceHedge() external nonReentrant {
        _balanceHedge(collateralBalance);
    }

    /// @notice '''_repayAsset''' is the completion of balanceHedge function
    /// @param amount is the amount  
    function _repayAsset(uint256 amount) public onlyAxelarRelay {
        uint256 _amountAssetShares =  fraxlend.toAssetShares(amount, true); 
        fraxlend.repayAsset(_amountAssetShares, hedge);
        emit AssetRepayed(amount);
    }
}
