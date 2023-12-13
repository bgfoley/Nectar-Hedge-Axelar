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
// import { IPerpsV2ExchangeRate, IPyth } from 'contracts/interfaces/Synthetix/IPerpsV2ExchangeRate.sol';
// May be able to bypass Kwenta through IPerpsV2 import { IAcounts } from 'Hedge/src/contracts/interfaces/IAccount.sol;';

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
                       ////      EVENTS      ////
//////================//////////////////////////=====================//////   


/// @dev need to add events



//////==================//////////////////////////===================//////
                       ////     MODIFIERS    ////
//////================//////////////////////////=====================//////   


    // we can change this to onlyStrategy so other strategies can use AxelarRelay
    // which will require further mods to codebase, but for now let's keep it simple
    modifier onlyHedge {
         require(msg.sender == hedge, "Hedge only");
        _;
    }

    // May need for cross chain calls
    modifier onlySelf() {
        require(msg.sender == address(this), 'Function must be called by the same contract only');
        _;
    }

    //
    modifier onlyPositionManager {
        require(msg.sender == positionManagerAddress, "Position Manager only");
        _;
    }


//////==================//////////////////////////===================//////
                       ////    CONSTRUCTOR   ////
//////================//////////////////////////=====================//////   


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
                       //////     READ     //////
//////================//////////////////////////=====================//////       



//////==================//////////////////////////===================//////
                       //////     WRITE    //////
//////================//////////////////////////=====================//////   


    // @notice 
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


    );

    function removeCollateralPlaceShort();
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
/*
    function addCollateralFraxlend(
        
        // string values passed by Position Manager
        string memory destinationChain,
        string memory destinationAddress,
        
        // collateralBalance - used to balance short if prices change during x-chain transfer
        uint256 calldata ,
        string memory symbol,
        uint256 toTarget
*/
  
    // Override AxelarExecutable to complete transaction
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
    /// to complete the sellShort functions
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

/*


    // init commands and inputs
    IAccount.Command[] memory commands = new IAccount.Command[](3);
    bytes[] memory inputs = new bytes[](3);

    // define commands
    commands[0] = IAccount.Command.ACCOUNT_MODIFY_MARGIN;
    commands[1] = IAccount.Command.PERPS_V2_MODIFY_MARGIN;
    commands[6] = IAccount.Command.PERPS_V2_SUBMIT_OFFCHAIN_DELAYED_ORDER;

    // define inputs
    inputs[0] = abi.encode(AMOUNT);
    inputs[1] = abi.encode(market, marginDelta);
    inputs[6] = abi.encode(market, sizeDelta, desiredFillPrice);

    // execute commands w/ inputs
    account.execute(commands, inputs);

    // delayed off-chain order details
    address market = getMarketAddressFromKey(sETHPERP);
    int256 marginDelta = int256(AMOUNT) / 10;
    int256 sizeDelta = 1 ether;
    (uint256 desiredFillPrice,) =
    IPerpsV2MarketConsolidated(market).assetPrice();

    */