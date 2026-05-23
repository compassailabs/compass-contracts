// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { LibDiamond } from "./libraries/LibDiamond.sol";
import { LibCompassStorage } from "./libraries/LibCompassStorage.sol";
import { LibUpgradeAuthority } from "./libraries/LibUpgradeAuthority.sol";
import { IAccount } from "./interfaces/IAccount.sol";
import { IERC20 } from "./interfaces/IERC20.sol";

contract InitCompass {
    struct InitArgs {
        address entryPoint;
        address usdc;
        address gatewayWallet;
        address gatewayMinter;
        address aavePool;
        address upgradeAuthority;
        address paymaster;
    }

    function init(InitArgs calldata a) external {
        LibCompassStorage.AppStorage storage s = LibCompassStorage.appStorage();
        s.entryPoint = a.entryPoint;
        s.usdc = a.usdc;
        s.gatewayWallet = a.gatewayWallet;
        s.gatewayMinter = a.gatewayMinter;
        s.aavePool = a.aavePool;

        LibUpgradeAuthority.s().authority = a.upgradeAuthority;
        LibUpgradeAuthority.s().revoked = false;

        LibDiamond.diamondStorage().supportedInterfaces[type(IAccount).interfaceId] = true;

        if (a.paymaster != address(0)) {
            IERC20(a.usdc).approve(a.paymaster, type(uint256).max);
        }
    }
}
