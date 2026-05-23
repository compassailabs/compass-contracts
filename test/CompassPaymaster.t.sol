// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Test } from "forge-std/Test.sol";
import { CompassPaymaster } from "../src/CompassPaymaster.sol";
import { IPaymaster } from "../src/interfaces/IPaymaster.sol";
import { PackedUserOperation } from "../src/interfaces/IAccount.sol";

contract MockUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "allowance");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockEntryPoint {
    function callValidate(
        CompassPaymaster pm,
        PackedUserOperation calldata userOp,
        bytes32 hash,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 validationData) {
        return pm.validatePaymasterUserOp(userOp, hash, maxCost);
    }

    function callPostOp(
        CompassPaymaster pm,
        IPaymaster.PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualFeePerGas
    ) external {
        pm.postOp(mode, context, actualGasCost, actualFeePerGas);
    }
}

contract CompassPaymasterTest is Test {
    CompassPaymaster pm;
    MockUSDC usdc;
    MockEntryPoint ep;
    address diamond = address(0xD1AAA);
    address owner = address(this);

    uint256 constant ETH_USD = 4000;
    uint256 constant MARKUP = 1000; // 10%

    function setUp() public {
        ep = new MockEntryPoint();
        usdc = new MockUSDC();
        pm = new CompassPaymaster(address(ep), owner, ETH_USD, MARKUP);
        pm.setUsdc(address(usdc));

        // Simulate Diamond holding USDC + having pre-approved the paymaster
        // (this is what InitCompass.init does at deploy time).
        usdc.mint(diamond, 1_000_000 * 1e6); // 1M USDC
        vm.prank(diamond);
        usdc.approve(address(pm), type(uint256).max);
    }

    function _emptyOp(address sender) internal pure returns (PackedUserOperation memory op) {
        op.sender = sender;
    }

    // Reference computation. 0.001 ETH at $4000 with 10% markup:
    // 1e15 wei * 4000 * 11000 / 1e16 = 4.4 USDC = 4_400_000 (6-dec).
    function test_quote_math() public view {
        assertEq(pm.quoteUsdcForGas(1e15), 4_400_000);
        assertEq(pm.quoteUsdcForGas(0), 0);
    }

    function test_validate_pulls_usdc_upfront() public {
        PackedUserOperation memory op = _emptyOp(diamond);
        uint256 maxCost = 1e15; // 0.001 ETH
        uint256 expectedPull = pm.quoteUsdcForGas(maxCost);

        uint256 balBefore = usdc.balanceOf(diamond);
        (bytes memory ctx, uint256 vd) = ep.callValidate(pm, op, bytes32(0), maxCost);

        assertEq(vd, 0, "validationData should be 0 (valid)");
        assertEq(usdc.balanceOf(diamond), balBefore - expectedPull, "Diamond debited prepaid amount");
        assertEq(usdc.balanceOf(address(pm)), expectedPull, "Paymaster received prepaid amount");

        (address d, uint256 prepaid) = abi.decode(ctx, (address, uint256));
        assertEq(d, diamond);
        assertEq(prepaid, expectedPull);
    }

    function test_postop_refunds_difference() public {
        PackedUserOperation memory op = _emptyOp(diamond);
        uint256 maxCost = 1e15;
        (bytes memory ctx, ) = ep.callValidate(pm, op, bytes32(0), maxCost);
        uint256 prepaid = pm.quoteUsdcForGas(maxCost);

        // Actual gas was half the max — Diamond should be refunded half (minus markup).
        uint256 actual = maxCost / 2;
        uint256 actualUsdc = pm.quoteUsdcForGas(actual);

        uint256 balBefore = usdc.balanceOf(diamond);
        ep.callPostOp(pm, IPaymaster.PostOpMode.opSucceeded, ctx, actual, 0);

        assertEq(usdc.balanceOf(diamond), balBefore + (prepaid - actualUsdc), "refund == max - actual");
        assertEq(usdc.balanceOf(address(pm)), actualUsdc, "paymaster keeps actual");
    }

    function test_postop_no_refund_when_actual_exceeds_prepaid() public {
        PackedUserOperation memory op = _emptyOp(diamond);
        uint256 maxCost = 1e15;
        (bytes memory ctx, ) = ep.callValidate(pm, op, bytes32(0), maxCost);
        uint256 prepaid = pm.quoteUsdcForGas(maxCost);

        // Pretend gas surged — actual cost > prepaid. Paymaster shouldn't
        // try to claw back more (Diamond's USDC is already gone).
        uint256 balBefore = usdc.balanceOf(diamond);
        ep.callPostOp(pm, IPaymaster.PostOpMode.opSucceeded, ctx, maxCost * 2, 0);

        assertEq(usdc.balanceOf(diamond), balBefore, "no refund on overshoot");
        assertEq(usdc.balanceOf(address(pm)), prepaid, "paymaster keeps it all");
    }

    function test_validate_reverts_without_allowance() public {
        // Fresh diamond that never approved.
        address freshDiamond = address(0xD2BBB);
        usdc.mint(freshDiamond, 100 * 1e6);
        PackedUserOperation memory op = _emptyOp(freshDiamond);

        vm.expectRevert();
        ep.callValidate(pm, op, bytes32(0), 1e15);
    }

    function test_only_entrypoint_can_validate() public {
        PackedUserOperation memory op = _emptyOp(diamond);
        vm.expectRevert(bytes("not EntryPoint"));
        pm.validatePaymasterUserOp(op, bytes32(0), 1e15);
    }

    function test_only_entrypoint_can_postop() public {
        bytes memory ctx = abi.encode(diamond, uint256(1e6));
        vm.expectRevert(bytes("not EntryPoint"));
        pm.postOp(IPaymaster.PostOpMode.opSucceeded, ctx, 1e15, 0);
    }

    function test_owner_can_set_rate_and_markup() public {
        pm.setEthUsdRate(5000);
        assertEq(pm.ethUsdRate(), 5000);

        pm.setMarkupBps(2000);
        assertEq(pm.markupBps(), 2000);
    }

    function test_non_owner_cannot_set_rate() public {
        vm.prank(address(0xBAD));
        vm.expectRevert();
        pm.setEthUsdRate(1);
    }

    function test_sweep_usdc() public {
        usdc.mint(address(pm), 500 * 1e6);
        address dst = address(0xBEEF);
        pm.sweepUsdc(dst, 500 * 1e6);
        assertEq(usdc.balanceOf(dst), 500 * 1e6);
    }

    function test_constructor_validates_inputs() public {
        vm.expectRevert(bytes("zero addr"));
        new CompassPaymaster(address(0), owner, ETH_USD, MARKUP);

        vm.expectRevert(bytes("zero rate"));
        new CompassPaymaster(address(ep), owner, 0, MARKUP);

        vm.expectRevert(bytes("markup > 50%"));
        new CompassPaymaster(address(ep), owner, ETH_USD, 5001);
    }

    function test_setUsdc_is_one_shot() public {
        // Fresh paymaster (setUp's already bound usdc on `pm`).
        CompassPaymaster fresh = new CompassPaymaster(address(ep), owner, ETH_USD, MARKUP);
        assertEq(address(fresh.usdc()), address(0));

        fresh.setUsdc(address(usdc));
        assertEq(address(fresh.usdc()), address(usdc));

        // Cannot re-bind.
        MockUSDC other = new MockUSDC();
        vm.expectRevert(bytes("usdc already set"));
        fresh.setUsdc(address(other));
    }

    function test_setUsdc_rejects_zero() public {
        CompassPaymaster fresh = new CompassPaymaster(address(ep), owner, ETH_USD, MARKUP);
        vm.expectRevert(bytes("zero usdc"));
        fresh.setUsdc(address(0));
    }

    function test_setUsdc_only_owner() public {
        CompassPaymaster fresh = new CompassPaymaster(address(ep), owner, ETH_USD, MARKUP);
        vm.prank(address(0xBAD));
        vm.expectRevert();
        fresh.setUsdc(address(usdc));
    }

    function test_validate_reverts_when_usdc_unset() public {
        CompassPaymaster fresh = new CompassPaymaster(address(ep), owner, ETH_USD, MARKUP);
        PackedUserOperation memory op = _emptyOp(diamond);
        vm.expectRevert(bytes("usdc not set"));
        ep.callValidate(fresh, op, bytes32(0), 1e15);
    }
}
