// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console2 } from "forge-std/Test.sol";
import { Diamond, DiamondArgs } from "src/Diamond.sol";
import { IDiamond, IDiamondCut } from "src/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "src/interfaces/IDiamondLoupe.sol";
import { OwnershipFacet } from "src/facets/OwnershipFacet.sol";
import { DiamondCutFacet } from "src/facets/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "src/facets/DiamondLoupeFacet.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { Test1Facet } from "src/test/Test1Facet.sol";
import { DiamondInit } from "src/upgradeInitializers/DiamondInit.sol";

contract DiamondTestBase is Test {
    Diamond internal diamond;
    IDiamondCut internal iDiamondCutFacet;
    IDiamondLoupe internal iDiamondLoupeFacet;
    IERC173 internal iOwnershipFacet;

    DiamondCutFacet internal diamondCutFacet;
    DiamondLoupeFacet internal diamondLoupeFacet;
    OwnershipFacet internal ownershipFacet;


    function _deploy() internal returns (Diamond diamond_) {
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();

        // TODO: Refactor to get all function selectors in a interface
        bytes4[] memory diamondCutFacetSelectors = new bytes4[](1);
        diamondCutFacetSelectors[0] = IDiamondCut(address(0)).diamondCut.selector;

        bytes4[] memory diamondLoupeFacetSelectors = new bytes4[](5);
        diamondLoupeFacetSelectors[0] = IDiamondLoupe.facets.selector;
        diamondLoupeFacetSelectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        diamondLoupeFacetSelectors[2] = IDiamondLoupe.facetAddresses.selector;
        diamondLoupeFacetSelectors[3] = IDiamondLoupe.facetAddress.selector;
        diamondLoupeFacetSelectors[4] = IERC165.supportsInterface.selector;

        bytes4[] memory ownershipFacetSelectors = new bytes4[](2);
        ownershipFacetSelectors[0] = IERC173.transferOwnership.selector;
        ownershipFacetSelectors[1] = IERC173.owner.selector;

        IDiamond.FacetCut[] memory _diamondCut = new IDiamond.FacetCut[](3);
        _diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: diamondCutFacetSelectors
        });
        _diamondCut[1] = IDiamond.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: diamondLoupeFacetSelectors
        });
        _diamondCut[2] = IDiamond.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ownershipFacetSelectors
        });

        DiamondInit diamondInit = new DiamondInit();

        DiamondArgs memory _args = DiamondArgs({
            owner: address(this),
            init: address(diamondInit),
            initCalldata: abi.encodeCall(DiamondInit.init, ())
        });

        diamond_ = new Diamond(_diamondCut, _args);
    }

    function setUp() public virtual {
        diamond = _deploy();
        iDiamondCutFacet = IDiamondCut(address(diamond));
        iDiamondLoupeFacet = IDiamondLoupe(address(diamond));
        iOwnershipFacet = OwnershipFacet(address(diamond));
    }
}

contract AddTest1FacetSetup is DiamondTestBase {
    Test1Facet internal iTest1Facet;

    function setUp() public virtual override {
        super.setUp();

        Test1Facet test1Facet = new Test1Facet();
        IDiamond.FacetCut[] memory _diamondCut = new IDiamond.FacetCut[](1);
        bytes4[] memory test1FacetSelectors = new bytes4[](3);
        test1FacetSelectors[0] = Test1Facet.func1.selector;
        test1FacetSelectors[1] = Test1Facet.func2.selector;
        test1FacetSelectors[2] = Test1Facet.func3.selector;

        _diamondCut[0] = IDiamond.FacetCut({
            facetAddress: address(test1Facet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: test1FacetSelectors
        });

        iDiamondCutFacet.diamondCut(_diamondCut, address(0), "");
        iTest1Facet = Test1Facet(address(diamond));
    }
}

contract DiamondTest is DiamondTestBase {

    function test_FacetAddresses() public {
        address[] memory facetAddresses = iDiamondLoupeFacet.facetAddresses();
        assertEq(facetAddresses.length, 3);
    }

    function test_FacetFunctionSelectors() public {
        bytes4[] memory selectors = iDiamondLoupeFacet.facetFunctionSelectors(address(diamondCutFacet));
        assertEq(selectors.length, 1);

        selectors = iDiamondLoupeFacet.facetFunctionSelectors(address(diamondLoupeFacet));
        assertEq(selectors.length, 5);

        selectors = iDiamondLoupeFacet.facetFunctionSelectors(address(ownershipFacet));
        assertEq(selectors.length, 2);
    }

    function test_FacetAddress_AssociateSelectorsAndFacets() public {
        address facet = iDiamondLoupeFacet.facetAddress(IDiamondCut.diamondCut.selector);
        assertEq(facet, address(diamondCutFacet));
    }

    function test_Owner() public {
        address owner = iOwnershipFacet.owner();
        assertEq(owner, address(this));
    }

    function test_TransferOwnership() public {
        address newOwner = address(1);
        iOwnershipFacet.transferOwnership(newOwner);
        assertEq(iOwnershipFacet.owner(), newOwner);
    }

    function test_IERC165() public {
        assertTrue(IERC165(address(diamond)).supportsInterface(type(IERC173).interfaceId));
    }
}

contract TestAddFacet1 is AddTest1FacetSetup {
    function test_Test1Function() public {
        iTest1Facet.func1(address(1));
        assertEq(iTest1Facet.func2(), address(1));
    }
}
