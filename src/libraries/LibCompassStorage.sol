// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

library LibCompassStorage {
    bytes32 internal constant APP_STORAGE_POSITION = keccak256("compass.app.storage.v1");

    struct SessionData {
        uint64 expiresAt;
        bool active;
        mapping(bytes4 => bool) allowedSelectors;
    }

    struct AppStorage {
        address entryPoint;
        address usdc;
        address gatewayWallet;
        address gatewayMinter;
        address aavePool;
        mapping(address => SessionData) sessions;
    }

    function appStorage() internal pure returns (AppStorage storage s) {
        bytes32 pos = APP_STORAGE_POSITION;
        assembly { s.slot := pos }
    }
}
