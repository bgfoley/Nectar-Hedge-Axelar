// import { IPerpsV2ExchangeRate, IPyth } from 'contracts/interfaces/Synthetix/IPerpsV2ExchangeRate.sol';
// May be able to bypass Kwenta through IPerpsV2 import { IAcounts } from 'Hedge/src/contracts/interfaces/IAccount.sol;';
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