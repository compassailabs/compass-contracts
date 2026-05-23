// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { DiamondCutFacet } from "../src/facets/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "../src/facets/DiamondLoupeFacet.sol";
import { OwnershipFacet } from "../src/facets/OwnershipFacet.sol";
import { Account4337Facet } from "../src/facets/Account4337Facet.sol";
import { SecurityFacet } from "../src/facets/SecurityFacet.sol";
import { GatewayFacet } from "../src/facets/GatewayFacet.sol";
import { AaveFacet } from "../src/facets/AaveFacet.sol";
import { ProtocolUpgradeFacet } from "../src/facets/ProtocolUpgradeFacet.sol";
import { InitCompass } from "../src/InitCompass.sol";
import { CompassAccountFactory } from "../src/CompassAccountFactory.sol";
import { CompassCreate2 } from "../src/CompassCreate2.sol";

contract Deploy is Script {
    bytes32 constant SALT = keccak256("compass.deploy.v2");

    function run() external {
        vm.startBroadcast();

        CompassCreate2 deployer = new CompassCreate2{salt: SALT}();

        address dCut   = deployer.deploy(SALT, type(DiamondCutFacet).creationCode);
        address dLoupe = deployer.deploy(SALT, type(DiamondLoupeFacet).creationCode);
        address ownF   = deployer.deploy(SALT, type(OwnershipFacet).creationCode);
        address a4337  = deployer.deploy(SALT, type(Account4337Facet).creationCode);
        address sec    = deployer.deploy(SALT, type(SecurityFacet).creationCode);
        address gw     = deployer.deploy(SALT, type(GatewayFacet).creationCode);
        address aave   = deployer.deploy(SALT, type(AaveFacet).creationCode);
        address upg    = deployer.deploy(SALT, type(ProtocolUpgradeFacet).creationCode);
        address init   = deployer.deploy(SALT, type(InitCompass).creationCode);

        bytes memory factoryInit = abi.encodePacked(
            type(CompassAccountFactory).creationCode,
            abi.encode(dCut, dLoupe, ownF, a4337, sec, gw, aave, upg, init)
        );
        address factory = deployer.deploy(SALT, factoryInit);

        vm.stopBroadcast();

        console2.log("CompassCreate2       :", address(deployer));
        console2.log("DiamondCutFacet      :", dCut);
        console2.log("DiamondLoupeFacet    :", dLoupe);
        console2.log("OwnershipFacet       :", ownF);
        console2.log("Account4337Facet     :", a4337);
        console2.log("SecurityFacet        :", sec);
        console2.log("GatewayFacet         :", gw);
        console2.log("AaveFacet            :", aave);
        console2.log("ProtocolUpgradeFacet :", upg);
        console2.log("InitCompass          :", init);
        console2.log("CompassAccountFactory:", factory);
    }
}
