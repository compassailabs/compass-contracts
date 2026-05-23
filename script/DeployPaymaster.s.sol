// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { CompassPaymaster } from "../src/CompassPaymaster.sol";
import { CompassCreate2 } from "../src/CompassCreate2.sol";

contract DeployPaymaster is Script {
    bytes32 constant SALT = keccak256("compass.deploy.v1");

    address constant CREATE2_DEPLOYER = 0xb36136F0aE0942D17f4aD418F3726fAdC3267Ef2;
    address constant ENTRY_POINT = 0x433709009B8330FDa32311DF1C2AFA402eD8D009;
    address constant USDC = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;

    uint256 constant ETH_USD_RATE = 2000;
    uint256 constant MARKUP_BPS  = 1000;

    uint256 constant INITIAL_DEPOSIT = 0.01 ether;

    function run() external {
        require(CREATE2_DEPLOYER != address(0), "set CREATE2_DEPLOYER first");

        vm.startBroadcast();

        CompassCreate2 deployer = CompassCreate2(CREATE2_DEPLOYER);

        bytes memory initCode = abi.encodePacked(
            type(CompassPaymaster).creationCode,
            abi.encode(ENTRY_POINT, msg.sender, ETH_USD_RATE, MARKUP_BPS)
        );
        address pm = deployer.deploy(SALT, initCode);

        CompassPaymaster(payable(pm)).setUsdc(USDC);
        CompassPaymaster(payable(pm)).deposit{value: INITIAL_DEPOSIT}();

        vm.stopBroadcast();

        console2.log("CompassPaymaster :", pm);
        console2.log("create2 deployer :", CREATE2_DEPLOYER);
        console2.log("entryPoint       :", ENTRY_POINT);
        console2.log("usdc             :", USDC);
        console2.log("owner            :", msg.sender);
        console2.log("ethUsdRate       :", ETH_USD_RATE);
        console2.log("markupBps        :", MARKUP_BPS);
        console2.log("initialDeposit   :", INITIAL_DEPOSIT);
    }
}
