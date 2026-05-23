// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { LibCompassStorage } from "./LibCompassStorage.sol";

library LibSecurity {
    error SessionInactive(address agent);
    error SessionExpired(address agent, uint64 expiresAt);
    error SelectorNotAllowed(address agent, bytes4 selector);

    event SessionRegistered(address indexed agent, uint64 expiresAt, bytes4[] selectors);
    event SessionRevoked(address indexed agent);

    function registerSession(
        address agent,
        uint64 expiresAt,
        bytes4[] memory allowedSelectors
    ) internal {
        require(agent != address(0), "zero agent");
        require(expiresAt > block.timestamp, "expired");

        LibCompassStorage.SessionData storage s =
            LibCompassStorage.appStorage().sessions[agent];

        s.expiresAt = expiresAt;
        s.active = true;
        for (uint256 i; i < allowedSelectors.length; ++i) {
            s.allowedSelectors[allowedSelectors[i]] = true;
        }
        emit SessionRegistered(agent, expiresAt, allowedSelectors);
    }

    function revokeSession(address agent) internal {
        LibCompassStorage.SessionData storage s =
            LibCompassStorage.appStorage().sessions[agent];
        s.active = false;
        emit SessionRevoked(agent);
    }

    /// Reverts if (agent, selector) is not a currently-valid combination.
    function enforceSession(address agent, bytes4 selector) internal view {
        LibCompassStorage.SessionData storage s =
            LibCompassStorage.appStorage().sessions[agent];
        if (!s.active) revert SessionInactive(agent);
        if (block.timestamp >= s.expiresAt) revert SessionExpired(agent, s.expiresAt);
        if (!s.allowedSelectors[selector]) revert SelectorNotAllowed(agent, selector);
    }

    function isSessionValid(address agent, bytes4 selector) internal view returns (bool) {
        LibCompassStorage.SessionData storage s =
            LibCompassStorage.appStorage().sessions[agent];
        return s.active && block.timestamp < s.expiresAt && s.allowedSelectors[selector];
    }
}
