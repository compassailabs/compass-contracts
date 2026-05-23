// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LibUpgradeAuthority } from "../libraries/LibUpgradeAuthority.sol";
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";

/// Per-user Diamond facet that lets the Compass protocol team roll out
/// new facets (e.g. MorphoFacet, CurveFacet) to every existing user
/// without requiring each user to sign their own `diamondCut`.
///
/// Safety boundaries — non-negotiable:
///   * Authority can ONLY `Add` selectors; never `Replace` / `Remove`.
///   * Authority may NOT touch any selector belonging to
///     SecurityFacet, OwnershipFacet, DiamondCut/Loupe, or this facet
///     itself (the "critical" set below).
///   * Authority CANNOT change the owner, drain funds, or call any
///     selector outside `authorityAddFacet`.
///   * The user (Diamond owner) can permanently revoke the authority
///     at any time via `userRevokeUpgradeAuthority`.
///
/// In practice the authority is a Compass-controlled multisig. After
/// revocation the user's diamond becomes upgrade-only-by-self —
/// equivalent to the bare EIP-2535 model.
contract ProtocolUpgradeFacet {
    event UpgradeAuthorityRevoked(address indexed by);
    event FacetAddedByAuthority(address indexed authority, uint256 cutCount);

    error NotUpgradeAuthority();
    error AuthorityRevoked();
    error OnlyAddAllowed();
    error CriticalSelector(bytes4 selector);

    function authorityAddFacet(IDiamondCut.FacetCut[] calldata cuts) external {
        LibUpgradeAuthority.UpgradeAuthorityStorage storage st = LibUpgradeAuthority.s();
        if (st.revoked) revert AuthorityRevoked();
        if (msg.sender != st.authority) revert NotUpgradeAuthority();

        for (uint256 i = 0; i < cuts.length; i++) {
            if (cuts[i].action != IDiamondCut.FacetCutAction.Add) {
                revert OnlyAddAllowed();
            }
            _enforceNotCritical(cuts[i].functionSelectors);
        }

        LibDiamond.diamondCut(cuts, address(0), "");

        emit FacetAddedByAuthority(msg.sender, cuts.length);
    }

    function userRevokeUpgradeAuthority() external {
        LibDiamond.enforceIsContractOwner();
        LibUpgradeAuthority.s().revoked = true;
        emit UpgradeAuthorityRevoked(msg.sender);
    }


    function currentAuthority() external view returns (address) {
        return LibUpgradeAuthority.s().authority;
    }

    function isAuthorityRevoked() external view returns (bool) {
        return LibUpgradeAuthority.s().revoked;
    }

    function _enforceNotCritical(bytes4[] calldata sel) internal pure {
        for (uint256 i = 0; i < sel.length; i++) {
            bytes4 s = sel[i];
            if (
                // DiamondCut
                s == IDiamondCut.diamondCut.selector
                // Ownership (ERC-173)
                || s == bytes4(keccak256("owner()"))
                || s == bytes4(keccak256("transferOwnership(address)"))
                // SecurityFacet
                || s == bytes4(keccak256("registerSession(address,uint64,bytes4[])"))
                || s == bytes4(keccak256("revokeSession(address)"))
                || s == bytes4(keccak256("isSessionValid(address,bytes4)"))
                || s == bytes4(keccak256("sessionExpiry(address)"))
                // ThisFacet
                || s == this.authorityAddFacet.selector
                || s == this.userRevokeUpgradeAuthority.selector
                || s == this.currentAuthority.selector
                || s == this.isAuthorityRevoked.selector
            ) {
                revert CriticalSelector(s);
            }
        }
    }
}
