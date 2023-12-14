//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

//////===============================================================//////
//////===============================================================//////
//////          /  |  / / ________________ _______________           //////
//////         /   | / //  __//  _//_  __// __  //  __  //           //////
//////        / /| |/ //  __// /__  / /  / /_/ //  /_/ //            //////
//////_______/ / |   / \___/ \___/ / /  /_/ /_//__/ \_ \\____________//////
//////==================/////  AXELAR RELAY  /////===================//////
//////===============================================================//////

import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol';
import { AxelarExpressExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/express/AxelarExpressExecutable.sol';
import { IAxelarGateway } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';
import { IERC20 } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol';
import { IAxelarGasService } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol';
import { IPositionManager } from './interfaces/IPositionManager.sol';
import { IHedge } from './interfaces/IHedge.sol';


/// @notice the Axelar Relay facilitates cross chain transfers and message passing for Nectar products
contract AxelarRelay is AxelarExpressExecutable {


//////==================//////////////////////////===================//////
                       ////      STATE       ////
//////================//////////////////////////=====================//////   

    // Gas service interface
    IAxelarGasService public immutable gasService;
    // Position Manager Interface
    IPositionManager public immutable positionManager;
    // Hedge Interface
    IHedge public hedgeInterface; 
    // Hedge Address
    address public immutable hedge;
    // Position Manager Address
    address public immutable positionManagerAddress; 

//////==================//////////////////////////===================//////
                       ////     MODIFIERS    ////
//////================//////////////////////////=====================//////   

    /// @Dev we can change this to onlyStrategy so other strategies can use AxelarRelay
    modifier onlyHedge {
         require(msg.sender == hedge, "Hedge only");
        _;
    }
/*
    // May need for cross chain calls
    modifier onlySelf() {
        require(msg.sender == address(this), 'Function must be called by the same contract only');
        _;
    }
*/

    //
    modifier onlyPositionManager {
        require(msg.sender == positionManagerAddress, "Position Manager only");
        _;
    }

//////==================//////////////////////////===================//////
                       ////    CONSTRUCTOR   ////
//////================//////////////////////////=====================//////   

    /// @notice '''constructor''' is called once on contract deployment
    /// @param gateway_ Axelar Gateway contract address
    /// @param gasReceiver Axelar gas service pays for x-chain calls
    /// @param _hedge Address of Hedge contract
    /// @param _positionManagerAddress Address of Position Manager contract    

    constructor(
        address gateway_, 
        address gasReceiver_,
        address _hedge,
        address _positionManagerAddress) 
        AxelarExpressExecutable(gateway_) {
        gasService = IAxelarGasService(gasReceiver_);
        hedge = _hedge;
        positionManagerAddress = _positionManagerAddress;
        positionManager = IPositionManager(_positionManagerAddress);
        hedgeInterface = IHedge(_hedge);     
    }

//////==================//////////////////////////===================//////
                       //////     WRITE    //////
//////================//////////////////////////=====================//////   

    /// @notice '''addCollateralPlaceShort''' takes Frax and sends it x-chain
    /// through AxelarExpressExecutable and calls PositionManager contract
    /// @param destinationChain is the name of home network to perp dex
    /// @param destinationAddress is address of the PositionManager contract
    /// @param collateralBalance is the total collateral balance on Fraxlend
    /// Position Manager uses it to determine positionSize of short
    /// @param symbol is the symbol of the token being transferred, which is
    /// required by Axelar for x-chain transfer
    /// @param toTarget is the amount of stablecoin to add as collateral   
    function addCollateralPlaceShort(
        // string values passed by Hedge
        string memory destinationChain,
        string memory destinationAddress,
        
        // collateralBalance - used to balance short
        uint256 collateralBalance,
        string memory symbol,
        uint256 toTarget
        ) external payable onlyHedge {
        require(msg.value > 0, 'Gas payment is required');
        address tokenAddress = gateway.tokenAddresses(symbol);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), toTarget);
        IERC20(tokenAddress).approve(address(gateway), toTarget);
        bytes memory payload = abi.encode(collateralBalance);
        gasService.payNativeGasForExpressCallWithToken{ value: msg.value }(
            address(this),
            destinationChain,
            destinationAddress,
            payload,
            symbol,
            toTarget,
            msg.sender
        );
        gateway.callContractWithToken(destinationChain, destinationAddress, payload, symbol, toTarget);
    }
    /// @notice '''addCollateralSellShort''' takes Frax and sends it x-chain
    /// through AxelarExpressExecutable and calls PositionManager contract
    /// @param destinationChain is the name of home network to perp dex
    /// @param destinationAddress is address of the PositionManager contract
    /// @param collateralNeeded is the dollar value of short that needs to be
    /// sold and transfered back to Fraxlend
    /// @param symbol is the symbol of the token being transferred, which is
    /// required by Axelar for x-chain transfer
    /// @param toTarget is the amount of stablecoin to add as collateral   
    function addCollateralSellShort(
        // string values passed by Hedge
        string memory destinationChain,
        string memory destinationAddress,
        
        // collateralBalance - used to balance short
        uint256 collateralNeeded,
        string memory symbol,
        uint256 toTarget
        ) external payable onlyHedge {
        require(msg.value > 0, 'Gas payment is required');
        address tokenAddress = gateway.tokenAddresses(symbol);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), toTarget);
        IERC20(tokenAddress).approve(address(gateway), toTarget);
        bytes memory payload = abi.encode(collateralNeeded);
        gasService.payNativeGasForExpressCallWithToken{ value: msg.value }(
            address(this),
            destinationChain,
            destinationAddress,
            payload,
            symbol,
            toTarget,
            msg.sender
        );
        gateway.callContractWithToken(destinationChain, destinationAddress, payload, symbol, toTarget);
    }
    
    /// @notice '''removeCollateralPlaceShort''' takes Frax and sends it x-chain
    /// through AxelarExpressExecutable and calls PositionManager contract
    /// @param destinationChain is the name of home network to perp dex
    /// @param destinationAddress is address of the PositionManager contract
    /// @param collateralBalance is the total collateral balance on Fraxlend
    /// Position Manager uses it to determine and adjust positionSize of short
    /// @param symbol is the symbol of the token being transferred, which is
    /// required by Axelar for x-chain transfer
    /// @param toTarget is the amount of stablecoin to remove as collateral   
    function removeCollateralPlaceShort(
    // string values passed by Hedge
        string memory destinationChain,
        string memory destinationAddress,
        
        // collateralBalance - used to balance short
        uint256 collateralBalance,
        string memory symbol,
        uint256 toTarget
        ) external payable onlyHedge {
        require(msg.value > 0, 'Gas payment is required');
        address tokenAddress = gateway.tokenAddresses(symbol);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), toTarget);
        IERC20(tokenAddress).approve(address(gateway), toTarget);
        bytes memory payload = abi.encode(collateralBalance);
        gasService.payNativeGasForExpressCallWithToken{ value: msg.value }(
            address(this),
            destinationChain,
            destinationAddress,
            payload,
            symbol,
            toTarget,
            msg.sender
        );
        gateway.callContract(destinationChain, destinationAddress, payload);
    }

    /// @notice '''removeCollateralSellShort''' takes Frax and sends it x-chain
    /// through AxelarExpressExecutable and calls PositionManager contract
    /// @param destinationChain is the name of home network to perp dex
    /// @param destinationAddress is address of the PositionManager contract
    /// @param collateralNeeded is the dollar value of short that needs to be
    /// sold and transfered back to Fraxlend
    /// @param toTarget is the amount of stablecoin to remove as collateral 
    function removeCollateralSellShort(
        
        // string values passed by Hedge
        string memory destinationChain,
        string memory destinationAddress,
        
        // to balance short
        uint256 collateralNeeded,
        uint256 toTarget
        ) external payable onlyHedge {
        require(msg.value > 0, 'Gas payment is required');
        bytes memory payload = abi.encode(collateralNeeded, toTarget);
        gasService.payNativeGasForExpressCall{ value: msg.value }(    
            address(this),
            destinationChain,
            destinationAddress,
            payload,
            msg.sender
        );
        gateway.callContract(destinationChain, destinationAddress, payload);      
    } 
  
    /// @notice Override AxelarExecutable to complete transactions w/ x-chain transfers
    function _executeWithToken(
        string calldata,
        string calldata,
        bytes calldata payload,
        string calldata tokenSymbol,
        uint256 amount
        ) internal override {
        
        // query gateway to get the tokenAddress
        address tokenAddress = gateway.tokenAddresses(tokenSymbol);
        
        // decode payload  positionSize
        uint256 positionSize = abi.decode(payload, (uint256));
        
        // Add collaterall to short position                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       
        positionManager.addCollateral(amount);

        // Adjust the short position
        positionManager.balanceShort(positionSize);
    }


    /// @notice internal override of Axelar Express Executable
    /// to complete x-chain contract calls, w/out token transfer
    function _execute(
        string calldata,
        string calldata,
        bytes calldata payload
    )   internal override {
        
        // decode payload
        (uint256 positionSize, uint256 collateralAmount) = abi.decode(payload, (uint256, uint256));
        
        //Remove collateral from short position
        positionManager.sellShort(collateralAmount);

        // Balance short position
        positionManager.balanceShort(positionSize);
    }
}

