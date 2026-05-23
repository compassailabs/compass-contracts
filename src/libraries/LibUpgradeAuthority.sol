// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

library LibUpgradeAuthority {
    bytes32 internal constant SLOT = keccak256("compass.upgrade.authority.v1");

    struct UpgradeAuthorityStorage {
        address authority;
        bool revoked;
    }

    function s() internal pure returns (UpgradeAuthorityStorage storage st) {
        bytes32 position = SLOT;
        assembly { st.slot := position }
    }
}
