// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

contract AxelarRelay {
    // Function to remove collateral
    function sellShort(
        string memory destinationChain,
        string memory destinationAddress,
        uint256 collateralBalance,
        uint256 toTarget
    ) external {
        // Perform logic here
        // For demonstration, print the values
        emit RemovalSuccess(destinationChain, destinationAddress, collateralBalance, toTarget);
    }

    // Function to add collateral and place a short
    function addCollateralPlaceShort(
        string memory destinationChain,
        string memory destinationAddress,
        uint256 collateralBalance,
        string memory symbol,
        uint256 toTarget
    ) external {
        // Perform logic here
        // For demonstration, print the values
        emit AdditionSuccess(destinationChain, destinationAddress, collateralBalance, symbol, toTarget);
    }

    // Events to signal success and log arguments
    event RemovalSuccess(
        string destinationChain,
        string destinationAddress,
        uint256 collateralBalance,
        uint256 toTarget
    );

    event AdditionSuccess(
        string destinationChain,
        string destinationAddress,
        uint256 collateralBalance,
        string symbol,
        uint256 toTarget
    );
}
