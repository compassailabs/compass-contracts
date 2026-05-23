// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

library LibMeta {
    /// Returns the original sender even when called via a meta-transaction
    /// (last 20 bytes of calldata when msg.sender == address(this)).
    function msgSender() internal view returns (address sender) {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
        } else {
            sender = msg.sender;
        }
    }
}
