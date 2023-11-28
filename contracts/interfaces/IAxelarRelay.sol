// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

interface IAxelarRelay {
    // Function to remove collateral
    function sellShort(
        string memory destinationChain,
        string memory destinationAddress,
        uint256 collateralBalance,
        uint256 toTarget
    ) external;

    // Function to add collateral and place a short
    function addCollateralPlaceShort(
        string memory destinationChain,
        string memory destinationAddress,
        uint256 collateralBalance,
        string memory symbol,
        uint256 toTarget
    ) external;
}
