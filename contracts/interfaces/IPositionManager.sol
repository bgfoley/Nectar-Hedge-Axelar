// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IPositionManager {
     
    function addCollateral(uint256 _amount) external;

    function removeCollateral(uint256 _amount) external;

    function balanceShort(uint256 positionSize) external;

}