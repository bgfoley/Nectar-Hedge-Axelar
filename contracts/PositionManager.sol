//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol';
import { AxelarExpressExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/express/AxelarExpressExecutable.sol';
import { IAxelarGateway } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';
import { IERC20 } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol';
import { IAxelarGasService } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol';
// import { IPerpsV2ExchangeRate, IPyth } from 'contracts/interfaces/Synthetix/IPerpsV2ExchangeRate.sol';
// // Should be able to bypass Kwenta through IPerpsV2 import { IAcounts } from 'Hedge/src/contracts/interfaces/IAccount.sol;';

// Should be able to bypass Kwenta through IPerpsV2 import { IFactory } from "src/interfaces/IFactory.sol";


contract PositionManager is AxelarExpressExecutable {
    IAxelarGasService public immutable gasService;
    address public immutable hedge; 
    // we'll change this to onlyStrategy so other strategies can use PositionManager
    // which will require further mods, but for now let's keep it simple
    modifier onlyHedge {
         require(msg.sender == hedge, "Hedge only");
        _;
    }
    // Needs for cross chain calls
    modifier onlySelf() {
        require(msg.sender == address(this), 'Function must be called by the same contract only');
        _;
    }
    
    constructor(
        address gateway_, 
        address gasReceiver_,
        address _hedge) 
        AxelarExpressExecutable(gateway_) {
        gasService = IAxelarGasService(gasReceiver_),
        hedge = _hedge;
    }

    function addCollateralPlaceShort(
        // string values passed by Hedge
        string memory destinationChain,
        string memory destinationAddress,
        // collateralBalance - used to balance short if prices change during x-chain transfer
        uint256 calldata collateralBalance,
        string memory symbol,
        uint256 toTarget
        ) external payable onlyHedge {
        require(msg.value > 0, 'Gas payment is required');
        address tokenAddress = gateway.tokenAddresses(symbol);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        IERC20(tokenAddress).approve(address(gateway), toTarget);
        bytes memory payload = abi.encode(collateralBalance);
        gasService.payNativeGasForExpressCallWithToken{ value: msg.value }(
            address(this),
            destinationChain,
            destinationAddress,
            payload,
            symbol,
            amount,
            msg.sender
        );
        gateway.callContractWithToken(destinationChain, destinationAddress, payload, symbol, toTarget);
    }

    function removeCollateral(
        string memory destinationChain,
        string memory destinationAddress,
        uint256 calldata collateralBalance,
        uint256 calldata toTarget
        ) external payable onlyHedge {
        require(msg.value > 0, 'Gas payment is required');
        bytes memory payload = abi.encode(collateralBalance, toTarget););
        gasService.payNativeGasForExpressCallWithToken{ value: msg.value }(    
            address(this),
            destinationChain,
            destinationAddress,
            payload,
            msg.sender
        );
        gateway.callContract(destinationChain, destinationAddress, payload);)
        
    } 

    function modifyMargin(uint256 amount) 

    function _executeWithToken(
        string calldata,
        string calldata,
        bytes calldata payload,
        string calldata tokenSymbol,
        uint256 amount
    ) internal override {
        // query gateway to get the tokenAddress
        address tokenAddress = gateway.tokenAddress(tokenSymbol);
        // decode payload
        uint256 totalEth = abi.decode(payload, collateralBalance);
        // swap tokens for sUSD
        // use tokenAddress for frax address argument
        // create IERC20 tokenAddress
        // approve uniswap
        // check margin if 0 initiate account
        // modify margin 3x short

        // get account info
        
                 {
            IERC20(tokenAddress).transfer(recipients[i], sentAmount);
        }
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