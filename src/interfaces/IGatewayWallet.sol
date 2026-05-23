// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IGatewayWallet {
    function deposit(address token, uint256 amount) external;
    function withdraw(address token, uint256 amount) external;
    function depositedBalance(address depositor, address token) external view returns (uint256);
}
