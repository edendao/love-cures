// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import {ActorSystem} from "./systems/ActorSystem.sol";

import {Hypercert} from "src/Hypercert.sol";
import {Evaluation} from "src/Evaluation.sol";

// 4. Researcher creates a Hyper IP NFT
// 5. Researcher fractionalizes the Hyper IP NFT
// 6. Investor buys Hyper IP NFT shares
// 7. Evaluators can create an Evaluation NFT
// 8. Researcher submits evaluated Hyper IP NFT to Prize Pool
// 9. Council reviews Hyper IP NFT & its Evaluations
// 10. Council creates a Vault for the Hyper IP NFT
// 11. Council assigns Impact Points
// 12. Researchers & Investors stake into the IP NFT vault
contract HyperIPNFTTest is ActorSystem {
    // Mock contracts pending final Hypercert & Evaluation standard from Filecoin
    Hypercert internal hypercert;
    Evaluation internal evaluation;

    function setUp() public virtual override {
        ActorSystem.setUp();

        hypercert = new Hypercert();
        evaluation = new Evaluation(address(hypercert));
    }

    function testCreatingHypercert() public returns (uint256 hypercertId) {
        vm.startPrank(researcher);
        hypercertId = hypercert.mint("Psychedelic Treatment Protocol #42");
        vm.stopPrank();

        assertEq(researcher, hypercert.creator(hypercertId));
    }

    function testCreatingEvaluation() public {
        uint256 hypercertId = testCreatingHypercert();

        vm.startPrank(evaluator);
        uint256 evaluationId = evaluation.mint(
            hypercertId,
            abi.encodePacked("Evaluation")
        );
        vm.stopPrank();

        assertEq(evaluator, evaluation.creator(evaluationId));
    }
}
