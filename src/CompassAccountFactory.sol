// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { CompassAccount } from "./CompassAccount.sol";
import { InitCompass } from "./InitCompass.sol";
import { IDiamondCut } from "./interfaces/IDiamondCut.sol";
import { IERC173 } from "./interfaces/IERC173.sol";

import { Account4337Facet } from "./facets/Account4337Facet.sol";
import { SecurityFacet } from "./facets/SecurityFacet.sol";
import { GatewayFacet } from "./facets/GatewayFacet.sol";
import { AaveFacet } from "./facets/AaveFacet.sol";
import { ProtocolUpgradeFacet } from "./facets/ProtocolUpgradeFacet.sol";

contract CompassAccountFactory {
    address public immutable diamondCutFacet;
    address public immutable diamondLoupeFacet;
    address public immutable ownershipFacet;
    address public immutable account4337Facet;
    address public immutable securityFacet;
    address public immutable gatewayFacet;
    address public immutable aaveFacet;
    address public immutable protocolUpgradeFacet;
    address public immutable initCompass;

    address[] public accounts;
    mapping(address => uint256) public accountIndex;

    event AccountCreated(
        address indexed owner,
        address indexed account,
        uint256 salt,
        uint256 indexed registryIndex
    );

    error AlreadyDeployed(address account);

    constructor(
        address _diamondCutFacet,
        address _diamondLoupeFacet,
        address _ownershipFacet,
        address _account4337Facet,
        address _securityFacet,
        address _gatewayFacet,
        address _aaveFacet,
        address _protocolUpgradeFacet,
        address _initCompass
    ) {
        diamondCutFacet = _diamondCutFacet;
        diamondLoupeFacet = _diamondLoupeFacet;
        ownershipFacet = _ownershipFacet;
        account4337Facet = _account4337Facet;
        securityFacet = _securityFacet;
        gatewayFacet = _gatewayFacet;
        aaveFacet = _aaveFacet;
        protocolUpgradeFacet = _protocolUpgradeFacet;
        initCompass = _initCompass;
    }

    function createAccount(
        address owner,
        uint256 salt,
        InitCompass.InitArgs calldata initArgs
    ) external returns (address account) {
        bytes32 finalSalt = _finalSalt(owner, salt);
        bytes memory bytecode = _accountCreationBytecode();

        assembly {
            account := create2(0, add(bytecode, 0x20), mload(bytecode), finalSalt)
        }
        require(account != address(0), "CREATE2 failed");
        if (accountIndex[account] != 0) revert AlreadyDeployed(account);

        IDiamondCut.FacetCut[] memory cuts = _buildFacetCuts();
        bytes memory initCalldata = abi.encodeWithSelector(InitCompass.init.selector, initArgs);
        IDiamondCut(account).diamondCut(cuts, initCompass, initCalldata);

        IERC173(account).transferOwnership(owner);

        accounts.push(account);
        uint256 registryIndex = accounts.length;
        accountIndex[account] = registryIndex;

        emit AccountCreated(owner, account, salt, registryIndex);
    }

    function getAccountAddress(address owner, uint256 salt) external view returns (address) {
        bytes32 finalSalt = _finalSalt(owner, salt);
        bytes32 bytecodeHash = keccak256(_accountCreationBytecode());
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), finalSalt, bytecodeHash)
        );
        return address(uint160(uint256(hash)));
    }

    function totalAccounts() external view returns (uint256) {
        return accounts.length;
    }

    function accountAt(uint256 i) external view returns (address) {
        return accounts[i];
    }

    function isFactoryAccount(address account) external view returns (bool) {
        return accountIndex[account] != 0;
    }

    function accountsRange(uint256 from, uint256 to) external view returns (address[] memory page) {
        uint256 len = accounts.length;
        if (from >= len) return new address[](0);
        if (to > len) to = len;
        uint256 n = to - from;
        page = new address[](n);
        for (uint256 i = 0; i < n; i++) {
            page[i] = accounts[from + i];
        }
    }

    function _finalSalt(address owner, uint256 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(owner, salt));
    }

    function _accountCreationBytecode() internal view returns (bytes memory) {
        return abi.encodePacked(
            type(CompassAccount).creationCode,
            abi.encode(address(this), diamondCutFacet, diamondLoupeFacet, ownershipFacet)
        );
    }

    function _buildFacetCuts() internal view returns (IDiamondCut.FacetCut[] memory cuts) {
        cuts = new IDiamondCut.FacetCut[](5);

        bytes4[] memory a4337 = new bytes4[](4);
        a4337[0] = Account4337Facet.validateUserOp.selector;
        a4337[1] = Account4337Facet.execute.selector;
        a4337[2] = Account4337Facet.executeBatch.selector;
        a4337[3] = Account4337Facet.entryPoint.selector;
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: account4337Facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: a4337
        });

        bytes4[] memory sec = new bytes4[](4);
        sec[0] = SecurityFacet.registerSession.selector;
        sec[1] = SecurityFacet.revokeSession.selector;
        sec[2] = SecurityFacet.isSessionValid.selector;
        sec[3] = SecurityFacet.sessionExpiry.selector;
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: securityFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: sec
        });

        bytes4[] memory gw = new bytes4[](3);
        gw[0] = GatewayFacet.depositToGateway.selector;
        gw[1] = GatewayFacet.withdrawFromGateway.selector;
        gw[2] = GatewayFacet.gatewayBalance.selector;
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: gatewayFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: gw
        });

        bytes4[] memory aave = new bytes4[](2);
        aave[0] = AaveFacet.supplyAave.selector;
        aave[1] = AaveFacet.withdrawAave.selector;
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: aaveFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: aave
        });

        bytes4[] memory upg = new bytes4[](4);
        upg[0] = ProtocolUpgradeFacet.authorityAddFacet.selector;
        upg[1] = ProtocolUpgradeFacet.userRevokeUpgradeAuthority.selector;
        upg[2] = ProtocolUpgradeFacet.currentAuthority.selector;
        upg[3] = ProtocolUpgradeFacet.isAuthorityRevoked.selector;
        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: protocolUpgradeFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: upg
        });
    }
}
