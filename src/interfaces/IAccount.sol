// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

struct PackedUserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    bytes32 accountGasLimits;   // verificationGasLimit << 128 | callGasLimit
    uint256 preVerificationGas;
    bytes32 gasFees;            // maxPriorityFeePerGas << 128 | maxFeePerGas
    bytes paymasterAndData;
    bytes signature;
}

interface IAccount {
    /// EntryPoint calls this during handleOps. Return 0 = valid;
    /// 1 = invalid; higher = packed validUntil/validAfter timestamps.
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData);
}
