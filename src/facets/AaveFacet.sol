// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LibCompassStorage } from "../libraries/LibCompassStorage.sol";
import { IERC20 } from "../interfaces/IERC20.sol";
import { IAavePool } from "../interfaces/IAavePool.sol";

contract AaveFacet {
    event AaveSupply(uint256 amount);
    event AaveWithdraw(uint256 amount);

    function supplyAave(uint256 amount) external {
        _requireAuth();
        LibCompassStorage.AppStorage storage s = LibCompassStorage.appStorage();
        if (amount == type(uint256).max) {
            amount = IERC20(s.usdc).balanceOf(address(this));
        }
        require(amount > 0, "zero supply");
        IERC20(s.usdc).approve(s.aavePool, amount);
        IAavePool(s.aavePool).supply(s.usdc, amount, address(this), 0);
        emit AaveSupply(amount);
    }

    function withdrawAave(uint256 amount) external {
        _requireAuth();
        LibCompassStorage.AppStorage storage s = LibCompassStorage.appStorage();
        IAavePool(s.aavePool).withdraw(s.usdc, amount, address(this));
        emit AaveWithdraw(amount);
    }

    function _requireAuth() internal view {
        LibCompassStorage.AppStorage storage s = LibCompassStorage.appStorage();
        require(
            msg.sender == s.entryPoint || msg.sender == LibDiamond.contractOwner(),
            "unauthorized"
        );
    }
}
