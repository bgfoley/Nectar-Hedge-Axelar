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
import { IFraxlendPair } from 'contracts/interfaces/IFraxlendPair.sol';
import { IAxelarRelay } from 'contracts/test/AxelarRelay.sol';

// Hedge is a product created by the geniuses at Nectar Development Co.

/// @notice Hedge is a one-click delta neutral positoning strategy 
contract Hedge is ReentrancyGuard {
    using Strings for address;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

//////==================//////////////////////////===================//////
                       ////      STATE       ////
//////================//////////////////////////=====================//////   
    
    /// User accounting

    // Store Eth deposited & depositShares of Hedge position 
    struct UserData {
    uint256 sfrxEthAmount;       // total sfrxEth deposited by user
    uint256 depositShares;       // value of user's hedge position
    }

    // Store user addresses against user balance data
    mapping(address => UserData) public userData; 

    /// Contract accounting

    // Hedge's collateral balance on fraxlend
    uint256 public collateralBalance = 0;

    // Hedge's total value locked
    uint256 public totalValueLocked = 0;

    // Hedge LTV
    uint256 public hedgeLtv;
   
    // For function balanceHedge
    uint256 public constant desiredHedgeLtv = 333333333333333333;
    
    // Hedge's address
    address payable public hedge;

    // Nectar Position Manager address
    address public immutable positionManager;
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
    

//////==================//////////////////////////===================//////
                       ////      EVENTS      ////
//////================//////////////////////////=====================////// 

    event Deposit(address indexed user, uint256 sfrxEthAmount, uint256 depositShares, uint256 collateralBalance, uint256 totalValueLocked);
    event Withdrawal(address indexed user, uint256 sfrxEthAmount, uint256 depositShares, uint256 collateralBalance, uint256 totalValueLocked);
    event AssetRepayed(uint256 indexed amount);
    event HedgeBalanced(uint256 totalValueLocked);

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
        address _fraxlendPair,          // (Mainnet) 0x78bB3aEC3d855431bd9289fD98dA13F9ebB7ef15
        address _fraxToken,             // (Mainnet) 0x853d955aCEf822Db058eb8505911ED77F175b99e
        address _sfrxEthToken,          // (Mainnet) 0xac3E018457B222d93114458476f3E3416Abbe38F
        address _axelarRelayAddress,    
        address _positionManager,       
        string memory _destinationChain // Use "Optimism" or "Arbitrum" (string) 
        )       
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
        destinationAddress = _positionManager.toHexString();
        symbol = IERC20Metadata(_fraxToken).symbol();                         
        hedgeLtv = getHedgeLtv();
        // Preapprove max allowance for contracts
        IERC20(_fraxToken).approve(_axelarRelayAddress, type(uint256).max);
        IERC20(_fraxToken).approve(_fraxlendPair, type(uint256).max);
        IERC20(_sfrxEthToken).approve(fraxlendPair, type(uint256).max);
    }
       
//////==================//////////////////////////===================//////
                       //////     READ     //////
//////================//////////////////////////=====================//////   

    /// @notice '''getHedgeLtv''' gets the loan health of Hedge's fraxlend account
    /// @dev revise math 
    /// @return hedge contract's loan to value ratio
    function getHedgeLtv() public view returns (uint256) {
        // get exchange rate
        (,uint224 exchangeRate) = fraxlend.exchangeRateInfo();
        uint256 sfrxEthExchangeRate = uint256(exchangeRate);
        
        // get loan info
        uint256 borrowShares = fraxlend.userBorrowShares(hedge);
        uint256 borrowAmount = fraxlend.toBorrowAmount(borrowShares, true);
        
        // calculate loan health
        uint256 ltvNumerator = borrowAmount * sfrxEthExchangeRate * 1e5;
        uint256 ltvDenominator = collateralBalance * 1e18;
        uint256 hedgeLTV = ltvNumerator / ltvDenominator;
        
        // return LTV
        return hedgeLTV;
    }

    /// @notice '''getSfrxEthBalance''' gets available sfrxEth for account
    /// @param _account is address of the account holder
    function getSfrxEthBalance(address _account) public view returns (uint256) {
        // Get the user data
        UserData storage user = userData[_account];
        
        // Calculate user's share of totalValueLocked
        uint256 userShares = user.depositShares / totalValueLocked; 
        uint256 _sfrxEthBalance = userShares * collateralBalance;
        
        // Return sfrxEthBalance available for withdrawal
        return _sfrxEthBalance;
    }

//////==================//////////////////////////===================//////
                       //////     WRITE    //////
//////================//////////////////////////=====================//////

    /// @notice the '''_balanceHedge''' function maintains the delta neutral position of the Hedge
    /// by 1) check for a loan to Value of 1:3 in Fraxlend, then 2) call addCollateralPlaceShort 
    /// or removeCollateral to make up the difference on the perp dex side
    /// It is called internally by deposit and withdraw, or can be called
    /// externally by anyone willing to pay gas -- 
    /// @dev maybe a chron bot to trigger this every 15 min or so
    /// @param _collateralBalance is Hedge's fraxlend account sfrxEth balance 
    function _balanceHedge(uint256 _collateralBalance) internal {
        // Get exchange rate
        (,uint224 exchangeRate) = fraxlend.exchangeRateInfo();
        uint256 sfrxEthExchangeRate = uint256(exchangeRate);
        
        // Get borrow shares and borrow amount
        uint256 borrowShares = fraxlend.userBorrowShares(hedge);
        uint256 borrowAmount = fraxlend.toBorrowAmount(borrowShares, true);
    
        // Calculate Hedge's loan to value ratio
        uint256 ltvNumerator = borrowAmount * 1e5;
        uint256 ltvDenominator = ltvNumerator / 1e18;
        uint256 _hedgeLtv = ltvDenominator * 1e5 / _collateralBalance;

        // Calculate the target borrow amount for 1:3 LTV
        uint256 targetBorrowNumerator = _collateralBalance * 1e18;
        uint256 targetBorrowDenominator = targetBorrowNumerator * _hedgeLtv;
        uint256 targetBorrowAmount = targetBorrowDenominator / sfrxEthExchangeRate / 1e5;

        // If loan size is too large, remove collateral from the short position and repay loan
        if (_hedgeLtv > desiredHedgeLtv) {
            uint256 toTarget = targetBorrowAmount - desiredHedgeLtv;
            axelarRelay.removeCollateral(
                destinationChain,
                destinationAddress,
                _collateralBalance,
                toTarget
            );
        } 

        // If loan size is too small, borrow more and send to short position collateral
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

        // Emit HedgeBalanced event
        emit HedgeBalanced(totalValueLocked); 
    }

    /// @notice '''balanceHedge''' is an external function to trigger _balanceHedge
    /// @dev calls _balanceHedge and passes current collateralBalance as argument
    function balanceHedge() external nonReentrant {
        _balanceHedge(collateralBalance);
    }

    function _deposit(address _sender, uint256 _amount) internal {
        // Get the exchange rate between sfrxEth and frax, calculate depositShares 
        (,uint224 exchangeRate) = fraxlend.exchangeRateInfo();
        uint256 sfrxEthExchangeRate = uint256(exchangeRate);
        uint256 _depositShares = sfrxEthExchangeRate * _amount;
       
        // Update UserData
        UserData storage user = userData[_sender];
        user.sfrxEthAmount += _amount;
        user.depositShares += _depositShares;

        // Update collateralBalance
        collateralBalance += _amount;
        
        // Update TVL
        totalValueLocked += _depositShares;

        // Interactions
        if (_sender != address(this)) {

        // Transfer tokens from the user to Hedge 
        sfrxEth.safeTransferFrom(_sender, hedge, _amount);

        // Add to Fraxlend
        fraxlend.addCollateral(_amount, hedge);
        
        // Balance hedge
        _balanceHedge(collateralBalance);
        }

         // Emit deposit event
        emit Deposit(_sender, _amount, _depositShares, totalValueLocked);
    }

    /// @notice the '''deposit''' function takes user's sfrxEth and opens delta-neutral hedge
    /// @param _amount of sfrxEth deposit
    /// @notice depositShares == the amount available for withdrawal
    function deposit(uint256 _amount) external nonReentrant {
        // Check for valid deposit amount, get user's data
        require(_amount > 0, "Deposit amount must be greater than zero");
        
        _deposit((msg.sender), _amount);
    }

    /// @notice the '''withdraw''' function returns sfrxEth to the user
    /// @param _amount is the amount of sfrxEth
    /// @notice depositShares == the amount available for withdrawal
    function withdraw(uint256 _amount) external nonReentrant {
        // Check for valid withdrawal amount 
        require(_amount > 0, "Withdraw amount must be greater than zero");
        
        // Retrieve the user's data
        uint256 _sfrxEthBalance = getSfrxEthBalance(msg.sender);
        UserData storage user = userData[msg.sender];
        require(_sfrxEthBalance >= _amount, "Insufficient balance for withdrawal");
        
        // Remove collateral from Fraxlend, transfer from Hedge to msg.sender
        fraxlend.removeCollateral(_amount, hedge);
        sfrxEth.safeTransferFrom(hedge, msg.sender, _amount);
    
        // Update UserData 
        uint256 _withdrawAmount = _amount / _sfrxEthBalance;
        uint256 _depositShares = user.depositShares * _withdrawAmount;
        user.sfrxEthAmount -= _amount;
        user.depositShares -= _depositShares;
        
        // Update TVL
        totalValueLocked -= _depositShares;
        
        // Calculate new collateralBalance, then balance Hedge
        uint256 newCollateralBalance = fraxlend.userCollateralBalance(hedge) - _amount;
        _balanceHedge(newCollateralBalance);
        
        // Emit withdrawal event
        emit Withdrawal(msg.sender, _amount, _depositShares, totalValueLocked);
    }

    /// @notice '''_repayAsset''' is the completion of balanceHedge function
    /// @param amount is the amount  
    function _repayAsset(uint256 amount) external onlyAxelarRelay {
        uint256 _amountAssetShares =  fraxlend.toAssetShares(amount, true); 
        fraxlend.repayAsset(_amountAssetShares, hedge);
        emit AssetRepayed(amount);
    }
}