// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { PackedUserOperation } from "./interfaces/IAccount.sol";
import { IPaymaster, IEntryPointStake } from "./interfaces/IPaymaster.sol";

contract CompassPaymaster is IPaymaster, Ownable {
    using SafeERC20 for IERC20;

    IEntryPointStake public immutable entryPoint;
    IERC20 public usdc;

    uint256 public ethUsdRate;

    uint256 public markupBps;

    event RateUpdated(uint256 newRate);
    event MarkupUpdated(uint256 newBps);
    event UsdcSet(address indexed usdc);
    event GasCharged(address indexed diamond, uint256 ethGasCost, uint256 usdcCharged);
    event UsdcSwept(address indexed to, uint256 amount);

    constructor(
        address _entryPoint,
        address _owner,
        uint256 _ethUsdRate,
        uint256 _markupBps
    ) Ownable(_owner) {
        require(_entryPoint != address(0), "zero addr");
        require(_ethUsdRate > 0, "zero rate");
        require(_markupBps <= 5000, "markup > 50%"); // sanity cap
        entryPoint = IEntryPointStake(_entryPoint);
        ethUsdRate = _ethUsdRate;
        markupBps = _markupBps;
    }

    function setUsdc(address _usdc) external onlyOwner {
        require(address(usdc) == address(0), "usdc already set");
        require(_usdc != address(0), "zero usdc");
        usdc = IERC20(_usdc);
        emit UsdcSet(_usdc);
    }

    modifier onlyEntryPoint() {
        require(msg.sender == address(entryPoint), "not EntryPoint");
        _;
    }

    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32, /*userOpHash*/
        uint256 maxCost
    ) external override onlyEntryPoint returns (bytes memory context, uint256 validationData) {
        require(address(usdc) != address(0), "usdc not set");

        address diamond = userOp.sender;
        uint256 maxUsdc = _ethToUsdcWithMarkup(maxCost);
        usdc.safeTransferFrom(diamond, address(this), maxUsdc);

        context = abi.encode(diamond, maxUsdc);
        validationData = 0;
    }

    function postOp(
        PostOpMode, /*mode*/
        bytes calldata context,
        uint256 actualGasCost,
        uint256 /*actualUserOpFeePerGas*/
    ) external override onlyEntryPoint {
        (address diamond, uint256 prepaidUsdc) = abi.decode(context, (address, uint256));
        uint256 actualUsdc = _ethToUsdcWithMarkup(actualGasCost);

        if (actualUsdc < prepaidUsdc) {
            usdc.safeTransfer(diamond, prepaidUsdc - actualUsdc);
            emit GasCharged(diamond, actualGasCost, actualUsdc);
        } else {
            emit GasCharged(diamond, actualGasCost, prepaidUsdc);
        }
    }

    function _ethToUsdcWithMarkup(uint256 weiAmount) internal view returns (uint256) {
        if (weiAmount == 0) return 0;
        uint256 raw = weiAmount * ethUsdRate * (10_000 + markupBps);
        return raw / 1e16;
    }

    function quoteUsdcForGas(uint256 weiAmount) external view returns (uint256) {
        return _ethToUsdcWithMarkup(weiAmount);
    }

    function setEthUsdRate(uint256 newRate) external onlyOwner {
        require(newRate > 0, "zero rate");
        ethUsdRate = newRate;
        emit RateUpdated(newRate);
    }

    function setMarkupBps(uint256 newBps) external onlyOwner {
        require(newBps <= 5000, "markup > 50%");
        markupBps = newBps;
        emit MarkupUpdated(newBps);
    }

    function sweepUsdc(address to, uint256 amount) external onlyOwner {
        usdc.safeTransfer(to, amount);
        emit UsdcSwept(to, amount);
    }

    function deposit() external payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    function getDeposit() external view returns (uint256) {
        return entryPoint.balanceOf(address(this));
    }

    function addStake(uint32 unstakeDelaySec) external payable onlyOwner {
        entryPoint.addStake{value: msg.value}(unstakeDelaySec);
    }

    function unlockStake() external onlyOwner {
        entryPoint.unlockStake();
    }

    function withdrawStake(address payable to) external onlyOwner {
        entryPoint.withdrawStake(to);
    }

    function withdrawTo(address payable to, uint256 amount) external onlyOwner {
        entryPoint.withdrawTo(to, amount);
    }

    receive() external payable {}
}
