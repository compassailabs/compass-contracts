// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LibCompassStorage } from "../libraries/LibCompassStorage.sol";
import { IERC20 } from "../interfaces/IERC20.sol";
import { IGatewayWallet } from "../interfaces/IGatewayWallet.sol";

contract GatewayFacet {
    event GatewayDeposit(address indexed token, uint256 amount);
    event GatewayWithdraw(address indexed token, uint256 amount);

    function depositToGateway(uint256 amount) external {
        _requireAuth();
        LibCompassStorage.AppStorage storage s = LibCompassStorage.appStorage();
        IERC20(s.usdc).approve(s.gatewayWallet, amount);
        IGatewayWallet(s.gatewayWallet).deposit(s.usdc, amount);
        emit GatewayDeposit(s.usdc, amount);
    }

    function withdrawFromGateway(uint256 amount) external {
        _requireAuth();
        LibCompassStorage.AppStorage storage s = LibCompassStorage.appStorage();
        IGatewayWallet(s.gatewayWallet).withdraw(s.usdc, amount);
        emit GatewayWithdraw(s.usdc, amount);
    }

    function gatewayBalance() external view returns (uint256) {
        LibCompassStorage.AppStorage storage s = LibCompassStorage.appStorage();
        return IGatewayWallet(s.gatewayWallet).depositedBalance(address(this), s.usdc);
    }

    function _requireAuth() internal view {
        LibCompassStorage.AppStorage storage s = LibCompassStorage.appStorage();
        require(
            msg.sender == s.entryPoint || msg.sender == LibDiamond.contractOwner(),
            "unauthorized"
        );
    }
}
