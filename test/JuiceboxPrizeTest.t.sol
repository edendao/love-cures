// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "./systems/ActorSystem.sol";
import "./systems/JuiceboxSystem.sol";

contract JuiceboxPrizeTest is ActorSystem, JuiceboxSystem {
    function setUp() public override(ActorSystem, JuiceboxSystem) {
        JuiceboxSystem.setUp();
        ActorSystem.setUp();
    }

    function testJuiceboxPrizePool() public {
        // 1. Council forms permissionlessly and creates a Distribution Pool
        // Note: This is not required, but doing this first saves 1 transaction
        // because then the Prize Pool can be initialized with an outflow to the distribution pool.
        vm.startPrank(council);
        uint256 distributionPoolProjectId = createDistributionPool();
        vm.stopPrank();

        // 2. Ops creates a Prize Pool for recieving funding and paying out to the Distribution Pool
        vm.startPrank(ops);
        uint256 prizePoolTokensPerETH = 1000 * 1 ether;
        (uint256 prizePoolId, ) = createPrizePool(
            prizePoolTokensPerETH,
            distributionPoolProjectId
        );
        vm.stopPrank();

        {
            // 3. Philanthropists fund Prize through NFT sales (or other means)
            vm.startPrank(philanthropist);
            uint256 donation = 10 ether;
            uint256 expectedPrizeTokens = (donation * prizePoolTokensPerETH) /
                1 ether; // normalize
            this.pay{value: donation}(
                prizePoolId,
                donation,
                ETH,
                expectedPrizeTokens,
                "Donation Memo"
            );
            vm.stopPrank();
        }

        // 2. Researcher creates a project to fractionalize the Hyper IP NFT
        uint256 ipSplitterTokensPerETH = 1000 * 1 ether; // 1,000 tokens per ETH
        uint256 ipSplitterPoolId = createIPPoolPool(ipSplitterTokensPerETH);
        vm.stopPrank();

        {
            // 3. Investor buys Hyper IP NFTTokens
            vm.startPrank(investor);
            uint256 investment = 10 ether;
            uint256 expectedInvestmentTokens = (investment *
                ipSplitterTokensPerETH) / 1 ether; // normalize

            this.pay{value: investment}(
                ipSplitterPoolId,
                investment,
                ETH,
                expectedInvestmentTokens,
                "Investment Memo"
            );
            vm.stopPrank();
        }
    }
}
