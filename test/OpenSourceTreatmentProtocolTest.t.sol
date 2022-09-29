// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "solmate/test/utils/mocks/MockERC20.sol";

import "./systems/ActorSystem.sol";

import "src/IntellectualProperty.sol";
import "src/RandomizedControledTrial.sol";

contract OpenSourceTreatmentProtocolTest is ActorSystem {
    IntellectualProperty ip;
    RandomizedControledTrial rct;

    function setUp() public override {
        ActorSystem.setUp();

        ip = new IntellectualProperty(address(0));
        ip.setOwner(council);
        rct = new RandomizedControledTrial(address(0), address(ip));
        rct.setOwner(evaluator);
    }

    function testOpenSourceTreatmentProtocolLifecycle() public {
        uint256 ipID = ip.mint("metadataURL");

        IntellectualProperty.Hypothesis hypothesisState;
        IntellectualProperty.RCT rctState;

        (hypothesisState, rctState) = ip.stateOf(ipID);
        assertEq(
            uint256(hypothesisState),
            uint256(IntellectualProperty.Hypothesis.PROPOSED)
        );
        assertEq(uint256(rctState), uint256(IntellectualProperty.RCT.PROPOSED));

        vm.prank(council);
        ip.approveTreatmentProtocol(ipID);

        (hypothesisState, rctState) = ip.stateOf(ipID);
        assertEq(
            uint256(hypothesisState),
            uint256(IntellectualProperty.Hypothesis.PROPOSED)
        );
        assertEq(uint256(rctState), uint256(IntellectualProperty.RCT.APPROVED));

        vm.prank(evaluator);
        rct.register(ipID, 6, "evaluationMetadataURI");

        assertEq(rct.impactOf(ipID), 6);

        vm.prank(council);
        ip.updateHypothesis(ipID, IntellectualProperty.Hypothesis.PROVED);

        (hypothesisState, rctState) = ip.stateOf(ipID);
        assertEq(
            uint256(hypothesisState),
            uint256(IntellectualProperty.Hypothesis.PROVED)
        );
        assertEq(
            uint256(rctState),
            uint256(IntellectualProperty.RCT.COMPLETED)
        );
    }

    function testOnlyOwnerCanUpdateMetadata() public {
        uint256 ipID = ip.mint("metadataURL");
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(ops);
        ip.update(ipID, "newMetadataURL");
    }
}
