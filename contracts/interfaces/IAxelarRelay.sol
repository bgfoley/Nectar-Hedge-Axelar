// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

interface IAxelarRelay {
    // Function to add collateral and place a short
    function addCollateralPlaceShort(
        string memory destinationChain,
        string memory destinationAddress,
        uint256 collateralBalance,
        string memory symbol,
        uint256 toTarget
    ) external;

    function addCollateralSellShort(
        string memory destinationChain,
        string memory destinationAddress,
        uint256 collateralNeeded,
        string memory symbol,
        uint256 toTarget
    ) external;

    function removeCollateralPlaceShort(
        string memory destinationChain,
        string memory destinationAddress,
        uint256 collateralBalance,
        uint256 toTarget
    ) external;

    function removeCollateralSellShort(
        string memory destinationChain,
        string memory destinationAddress,
        uint256 collateralNeeded,
        uint256 toTarget
    ) external;

}
