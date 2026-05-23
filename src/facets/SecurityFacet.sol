// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LibCompassStorage } from "../libraries/LibCompassStorage.sol";
import { LibSecurity } from "../libraries/LibSecurity.sol";

contract SecurityFacet {
    function registerSession(
        address agent,
        uint64 expiresAt,
        bytes4[] calldata allowedSelectors
    ) external {
        LibDiamond.enforceIsContractOwner();
        LibSecurity.registerSession(agent, expiresAt, allowedSelectors);
    }

    function revokeSession(address agent) external {
        LibDiamond.enforceIsContractOwner();
        LibSecurity.revokeSession(agent);
    }

    function isSessionValid(address agent, bytes4 selector) external view returns (bool) {
        return LibSecurity.isSessionValid(agent, selector);
    }

    function sessionExpiry(address agent) external view returns (uint64) {
        return LibCompassStorage.appStorage().sessions[agent].expiresAt;
    }
}
