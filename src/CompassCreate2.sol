// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

contract CompassCreate2 {
    mapping(bytes32 => address) public deployedAt;

    event Deployed(bytes32 indexed salt, address indexed addr, address indexed caller);

    function deploy(bytes32 salt, bytes calldata initCode) external returns (address addr) {
        addr = Create2.deploy(0, salt, initCode);
        deployedAt[salt] = addr;
        emit Deployed(salt, addr, msg.sender);
    }

    function computeAddress(bytes32 salt, bytes32 bytecodeHash) external view returns (address) {
        return Create2.computeAddress(salt, bytecodeHash);
    }
}
