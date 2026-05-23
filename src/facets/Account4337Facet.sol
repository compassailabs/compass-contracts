// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { IAccount, PackedUserOperation } from "../interfaces/IAccount.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LibCompassStorage } from "../libraries/LibCompassStorage.sol";
import { LibSecurity } from "../libraries/LibSecurity.sol";

contract Account4337Facet is IAccount {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    uint256 internal constant SIG_VALIDATION_SUCCESS = 0;
    uint256 internal constant SIG_VALIDATION_FAILED = 1;

    /// Only the EntryPoint may call validateUserOp.
    modifier onlyEntryPoint() {
        require(msg.sender == LibCompassStorage.appStorage().entryPoint, "not EntryPoint");
        _;
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override onlyEntryPoint returns (uint256 validationData) {
        // 1) Recover signer with EIP-191 prefix (canonical ERC-4337 pattern).
        bytes32 signedHash = userOpHash.toEthSignedMessageHash();
        address signer = ECDSA.recover(signedHash, userOp.signature);

        // 2) Owner always valid.
        if (signer == LibDiamond.contractOwner()) {
            validationData = SIG_VALIDATION_SUCCESS;
        } else {
            // 3) Session-key path: callData[:4] must be in allowedSelectors.
            bytes4 entrySelector = bytes4(userOp.callData[:4]);
            validationData = LibSecurity.isSessionValid(signer, entrySelector)
                ? SIG_VALIDATION_SUCCESS
                : SIG_VALIDATION_FAILED;
        }

        // 4) Pay EntryPoint our share of gas prefund, if any.
        if (missingAccountFunds != 0) {
            (bool ok, ) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (ok); // ignore failure per ERC-4337 spec (EntryPoint will revert)
        }
    }

    function execute(address target, uint256 value, bytes calldata data) external {
        _requireAuth();
        (bool ok, bytes memory ret) = target.call{value: value}(data);
        if (!ok) {
            assembly {
                let returndata_size := mload(ret)
                revert(add(32, ret), returndata_size)
            }
        }
    }

    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external {
        _requireAuth();
        require(targets.length == values.length && values.length == datas.length, "length");
        for (uint256 i; i < targets.length; ++i) {
            (bool ok, bytes memory ret) = targets[i].call{value: values[i]}(datas[i]);
            if (!ok) {
                assembly {
                    let returndata_size := mload(ret)
                    revert(add(32, ret), returndata_size)
                }
            }
        }
    }

    function entryPoint() external view returns (address) {
        return LibCompassStorage.appStorage().entryPoint;
    }

    function _requireAuth() internal view {
        LibCompassStorage.AppStorage storage s = LibCompassStorage.appStorage();
        require(
            msg.sender == s.entryPoint ||
            msg.sender == LibDiamond.contractOwner() ||
            msg.sender == address(this),
            "unauthorized"
        );
    }
}
