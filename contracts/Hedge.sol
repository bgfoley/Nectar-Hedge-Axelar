//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

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
import { ReentrancyGuard } from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { SafeCast } from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import { Strings } from '@openzeppelin/contracts/utils/Strings.sol';
import { IFraxlendPair } from 'contracts/interfaces/IFraxlendPair.sol';
import { IAxelarRelay } from 'contracts/interfaces/IAxelarRelay.sol';

// Hedge is a product created by the geniuses at Nectar Development Co.

/// @notice Hedge is a one-click delta neutral strategy 
contract Hedge is ReentrancyGuard {
    using Strings for address;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

//////==================//////////////////////////===================//////
                       ////      STATE       ////
//////================//////////////////////////=====================//////   
    
    /// User level accounting
    /// @dev replace user level accounting with tokens - ie mint erc721s or 20s for user accounting 
    /// - allow mint of necUSD once short has been placed & confirmed
    // Store Eth deposited & depositShares of Hedge position 
    struct UserData {
    uint256 sfrxEthAmount;       // total sfrxEth deposited by user
    uint256 depositShares;       // value of user's hedge position
    }

    // Store user addresses against user balance data
    mapping(address => UserData) public userData; 

    /// Contract level accounting

    // Hedge's collateral balance on fraxlend
    uint256 public collateralBalance = 0;
    // Hedge's total value locked
    uint256 public totalValueLocked = 0;
    // Hedge's total borrowed
    uint256 public totalBorrowed = 0;
    // value of Hedge's collateral balance converted to dollars
    uint256 public collateralValue;
    // For balanceHedge function 
    uint256 public targetBorrowAmount;
     // Hedge's address
    address public immutable hedge;
    // Nectar Position Manager address
    address public immutable positionManager;
    // Balancer / Chron Job address
    address public immutable balancerAddress;
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
    event AssetRepayed(uint256 totalBorrowed);
    event CollateralAdded(uint256 collateralBalance);
    event HedgeBalanced(uint256 totalBorrowed);

//////==================//////////////////////////===================//////
                       ////     MODIFIERS    ////
//////================//////////////////////////=====================//////   

    modifier onlyAxelarRelay {
        require(msg.sender == axelarRelayAddress, "Axelar Relay contract only");
        _;
    }

    /// @dev consider removing this and making balance Hedge public - just have to verify security
    modifier onlyBalancer {
        require(msg.sender == balancerAddress, "Balancer contract only");
        _;
    }

//////==================//////////////////////////===================//////
                       ////    CONSTRUCTOR   ////
//////================//////////////////////////=====================//////   


    /// @dev - consider adding current constructor params to a data struct 
    /// that contains parameters for variations on Hedge. For example stEth
    /// and rEth, so that all Hedge products are contained in this contract
    /// Admin would call addToken, then enter params. Then user dep/with 
    /// would select a token (0-whatever)
    /// @notice '''constructor''' is called once on contract deployment
    /// @param _fraxlendPair for long position
    /// @param _fraxToken the borrowed token
    /// @param _sfrxEthToken the collateral token
    /// @param _axelarRelayAddress address of Nectar AxelarRelay contract
    /// @param _positionManager manages shorts on perp dex       
    /// @param _balancerAddress bot triggers balanceHedge function periodically
    /// @param _destinationChain for use by Axelar
    
    constructor(
        address _fraxlendPair,          // (Mainnet) 0x78bB3aEC3d855431bd9289fD98dA13F9ebB7ef15
        address _fraxToken,             // (Mainnet) 0x853d955aCEf822Db058eb8505911ED77F175b99e
        address _sfrxEthToken,          // (Mainnet) 0xac3E018457B222d93114458476f3E3416Abbe38F
        address _axelarRelayAddress,    
        address _positionManager,
        address _balancerAddress,       
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
        positionManager = _positionManager;
        balancerAddress = _balancerAddress;
        destinationAddress = _positionManager.toHexString();
        symbol = IERC20Metadata(_fraxToken).symbol();
        targetBorrowAmount = (totalValueLocked) / (3 * 1e18);                            
        collateralValue = getCollateralValue();
        // Preapprove max allowance for contracts
        IERC20(_fraxToken).approve(_axelarRelayAddress, type(uint256).max);
        IERC20(_fraxToken).approve(_fraxlendPair, type(uint256).max);
        IERC20(_sfrxEthToken).approve(fraxlendPair, type(uint256).max);
    }
       
//////==================//////////////////////////===================//////
                       //////     READ     //////
//////================//////////////////////////=====================//////   

    /// @notice '''getCollateralValue''' calculates the value of Hedge's collateral balance
    /// @return the dollar value of Hedge's collateral in Fraxlend
    function getCollateralValue() public view returns (uint256) {
        // get exchange rate
        (,uint224 exchangeRate) = fraxlend.exchangeRateInfo();
        uint256 sfrxEthExchangeRate = uint256(exchangeRate);

        // calculate value of collateralBalance
        uint256 _collateralValue = collateralBalance * sfrxEthExchangeRate;
        _collateralValue = collateralValue;

        // return collateral value
        return collateralValue;
    }
    
    /// @notice '''getSfrxEthBalance''' gets available sfrxEth for account
    /// @param _account is address of the account holder
    function getSfrxEthBalance(address _account) public view returns (uint256) {
        // Get the user data
        UserData storage user = userData[_account];
        
        // Calculate user's share of totalValueLocked
        uint256 usersShare = user.depositShares / totalValueLocked; 
        uint256 _sfrxEthBalance = usersShare * collateralBalance;
        
        // Return sfrxEthBalance available for withdrawal
        return _sfrxEthBalance;
    }

    /// @notice '''isSolvent''' returns a boolian representing Hedge's solvency 
    /// returns true if there is enough sfrxEth to cover the TVL
    function isSolvent() public view returns (bool) {
        // check Hedge's solvency
        if (collateralValue >= totalValueLocked){
            return true;
        }
        else {
            return false;
        }
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
    function _balanceHedge() public onlyBalancer {
        // Check Hedge's solvency
        if (isSolvent()) {
            // If loan size is too small, borrow more and send to short position collateral
            if (targetBorrowAmount > totalBorrowed) {
                uint256 toTarget = targetBorrowAmount -  totalBorrowed;
            
                // Update contract accounting
                totalBorrowed += toTarget;

                // Borrow asset from Fraxlend
                fraxlend.borrowAsset(toTarget, collateralBalance, hedge);

                // Send tokens across chain to add collateral and place short on perp dex
                axelarRelay.addCollateralPlaceShort(
                    destinationChain,
                    destinationAddress,
                    collateralBalance,
                    symbol,
                    toTarget
                );
            }    
       
            // If loan size is too large, withdraw collateral from perp dex and adjust short position for new positionSize
            else {
                uint256 toTarget = totalBorrowed - targetBorrowAmount;

                /// @dev Don't update contract accounting loan is repayed through cross chain transfer
                // Call Axelar relay to remove collateral from perp dex, update collateralBalance
                axelarRelay.removeCollateralPlaceShort(
                    destinationChain,
                    destinationAddress,
                    collateralBalance,
                    toTarget
                );
            }
        }

        // If Hedge is insolvent, adjust loan and call positionManager across chain to sell short
        else {

            // Calculate amount needed to make Hedge solvent
            uint256 collateralNeeded = totalValueLocked - collateralValue;

            // Check loan size, if too small, borrow more and send to short position collateral
            if (targetBorrowAmount > totalBorrowed) {
                uint256 toTarget = targetBorrowAmount -  totalBorrowed;
            
                // Update contract accounting
                totalBorrowed += toTarget;

                // Borrow asset from Fraxlend
                fraxlend.borrowAsset(toTarget, collateralBalance, hedge);

                // Call tokens across chain to sell short to make Hedge solvent and add collateral to perp dex
                axelarRelay.addCollateralSellShort(
                    destinationChain,
                    destinationAddress,
                    collateralNeeded,
                    symbol,
                    toTarget
                );
            }
            // If loan too large, calculate amount needed to payback
            else {
                uint256 toTarget = totalBorrowed - targetBorrowAmount;

                /// @dev Don't update contract accounting loan is repayed through cross chain transfer
                // Call Axelar relay to remove collateral from perp dex, update collateralBalance
                axelarRelay.removeCollateralSellShort(
                    destinationChain,
                    destinationAddress,
                    collateralNeeded,
                    toTarget
                );
            }

        }    

        // Emit HedgeBalanced event
        emit HedgeBalanced(totalBorrowed); 
    }

    /// @notice '''_deposit''' function is the internal implimentation of the deposit function
    /// @dev Caller must '''ERC20.approve''' the token (sfrxEth) before calling the function
    /// @param _sender the address of the user making the deposit
    /// @param _amount the amount of sfrxEth they have deposited
    function _deposit(address _sender, uint256 _amount) internal {
        // Get the exchange rate between sfrxEth and frax, calculate depositShares 
        (,uint224 exchangeRate) = fraxlend.exchangeRateInfo();
        uint256 sfrxEthExchangeRate = uint256(exchangeRate);
        uint256 _depositShares = sfrxEthExchangeRate * _amount;
       
        // Update UserData
        UserData storage user = userData[_sender];
        user.sfrxEthAmount += _amount;
        user.depositShares += _depositShares;

        // Update contract collateralBalance
        collateralBalance += _amount;
        
        // Update TVL
        totalValueLocked += _depositShares;

        // Interactions
        if (_sender != address(this)) {

        // Transfer tokens from the user to Hedge 
        sfrxEth.safeTransferFrom(_sender, hedge, _amount);

        // Add sfrxEth collateral to Fraxlend
        fraxlend.addCollateral(_amount, hedge);
        
        // Balance hedge
        _balanceHedge();
        }

         // Emit deposit event
        emit Deposit(_sender, _amount, _depositShares, collateralBalance, totalValueLocked);
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
        
        // Calculate user's avaiable sfrxEth
        uint256 _sfrxEthBalance = getSfrxEthBalance(msg.sender);
        require(_sfrxEthBalance >= _amount, "Insufficient balance for withdrawal");

        // Retrieve the user's data
        UserData storage user = userData[msg.sender];

        // Get fractional representation of withdrawal amount over sfrxEth available for withdrawal
        uint256 _withdrawPortion = _amount / _sfrxEthBalance;

        // Calculate withdrawal amount in terms of deposit shares 
        uint256 _depositSharesToWithdraw = user.depositShares * _withdrawPortion;

        // Update UserData 
        user.sfrxEthAmount -= _amount;
        user.depositShares -= _depositSharesToWithdraw;
        
        // Update TVL
        totalValueLocked -= _depositSharesToWithdraw;

        // Update collateralBalance
        collateralBalance -= _amount;
        
        // Remove collateral from Fraxlend, transfer from Hedge to msg.sender
        fraxlend.removeCollateral(_amount, hedge);
        sfrxEth.safeTransferFrom(hedge, msg.sender, _amount);
    
        // Balance Hedge
        _balanceHedge();
        
        // Emit withdrawal event
        emit Withdrawal(msg.sender, _amount, _depositSharesToWithdraw, collateralBalance, totalValueLocked);
    }

    /// @notice '''_repayAsset''' is the completion of balanceHedge function
    /// @param _amount is the amount  
    function _repayAsset(uint256 _amount) external onlyAxelarRelay {
        // Update totalBorrowed
        totalBorrowed += _amount;

        // Convert _amount to assetShares        
        uint256 _amountAssetShares =  fraxlend.toAssetShares(_amount, true); 

        fraxlend.repayAsset(_amountAssetShares, hedge);
        emit AssetRepayed(totalBorrowed);
    }

    /// @notice '''_addCollateral''' is the completion of balanceHedge function after short is sold
    /// @param _amount is the amount
    function _addCollateral(uint256 _amount) external onlyAxelarRelay {
        // Update collateralBalance
        collateralBalance += _amount;
        fraxlend.addCollateral(_amount, hedge);
        emit CollateralAdded(_amount);
    }
}
