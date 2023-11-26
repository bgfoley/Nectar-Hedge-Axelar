// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

contract PositionManager {
    // Event to log success and the argument value
    event OperationSuccess(uint256 value);

    function addCollateral(uint256 _amount) external {
        // Add collateral logic here
        // ...

        // Emit success event with the argument value
        emit OperationSuccess(_amount);
    }

    function removeCollateral(uint256 _amount) external {
        // Remove collateral logic here
        // ...

        // Emit success event with the argument value
        emit OperationSuccess(_amount);
    }

    function balanceShort(uint256 positionSize) external {
        // Balance short logic here
        // ...

        // Emit success event with the argument value
        emit OperationSuccess(positionSize);
    }
}
