// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "./systems/ActorSystem.sol";
import "./systems/HypercertSystem.sol";
import "./systems/JuiceboxSystem.sol";

contract JuiceboxPrizeTest is ActorSystem, HypercertSystem, JuiceboxSystem {
    function setUp()
        public
        override (ActorSystem, HypercertSystem, JuiceboxSystem)
    {
        JuiceboxSystem.setUp();
        HypercertSystem.setUp();
        ActorSystem.setUp();
    }

    function testJuiceboxPrizePool() public {
        // 1. Council forms permissionlessly and creates a Distribution Pool

        // Doing this first saves 1 transaction because then the Prize Pool
        // can be initialized with an outflow to the distribution pool.
        vm.startPrank(council);
        uint256 distributionPoolProjectId = createDistributionPool();
        vm.stopPrank();

        // 2. Ops creates a Prize Pool for recieving funding and paying out to the Distribution Pool
        vm.startPrank(ops);
        uint256 prizePoolTokensPerETH = 1000 * 1 ether;
        (uint256 prizePoolId,) =
            createPrizePool(prizePoolTokensPerETH, distributionPoolProjectId);
        vm.stopPrank();

        {
            // 3. Philanthropists fund Prize through NFT sales (or other means)
            vm.startPrank(philanthropist);
            uint256 donation = 10 ether;
            uint256 expectedPrizeTokens =
                donation * prizePoolTokensPerETH / 1 ether; // normalize
            this.pay{value: donation}(
                prizePoolId, donation, ETH, expectedPrizeTokens, "Donation Memo"
            );
            vm.stopPrank();
        }

        // 1. Researcher creates a Hyper IP NFT
        vm.startPrank(researcher);
        string memory hypercertName = "Psychedelic Treatment Protocol #42";
        uint256 hypercertId = hypercert.mint(bytes(hypercertName));
        assertEq(researcher, hypercert.creator(hypercertId));

        // 2. Researcher creates a project to fractionalize the Hyper IP NFT
        uint256 hyperIPNFTTokensPerETH = 1000 * 1 ether; // 1,000 tokens per ETH
        uint256 hyperIPNFTPoolId = createHyperIPNFTPool(hyperIPNFTTokensPerETH);
        vm.stopPrank();

        {
            // 3. Investor buys Hyper IP NFTTokens
            vm.startPrank(investor);
            uint256 investment = 10 ether;
            uint256 expectedInvestmentTokens =
                investment * hyperIPNFTTokensPerETH / 1 ether; // normalize

            this.pay{value: investment}(
                hyperIPNFTPoolId,
                investment,
                ETH,
                expectedInvestmentTokens,
                "Investment Memo"
            );
            vm.stopPrank();
        }

        // 4. Evaluators can create Evaluation NFT
        vm.startPrank(evaluator);
        uint256 evaluationId = evaluation.mint(
            hypercertId, abi.encodePacked("Evaluation of ", hypercertName)
        );
        vm.stopPrank();
        assertEq(evaluator, evaluation.creator(evaluationId));

        // 5. Researcher submits Hyper IP NFT to Prize Pool

        // 6. (off-chain) Council reviews Hyper IP NFT & Evaluations, then...
        // 7a. Accepts Hyper IP NFT
        // 7b. Assigns Impact Points
        // 7c. Creates IP NFT Vault
        // 7d. Updates drips for Prize Fund => IP NFT Vaults to be pro-rata
        // 8. Researcher & Investors:
        // 8a. Stake shares into IP NFT Vault
        // 8b. Updates drips for IP NFT Vault => Token Holders to be pro-rata
    }
}
