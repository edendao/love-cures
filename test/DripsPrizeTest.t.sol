// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "./systems/ActorSystem.sol";
import "./systems/HypercertSystem.sol";
import "./systems/DripsSystem.sol";

contract DripsPrizeTest is ActorSystem, HypercertSystem, DripsSystem {
    PrizePool internal prizePool;
    ImpactPool internal impactPool;

    function setUp()
        public
        override(ActorSystem, HypercertSystem, DripsSystem)
    {
        DripsSystem.setUp();
        HypercertSystem.setUp();
        ActorSystem.setUp();

        // 1. Ops sets up and manages their own PrizePool
        prizePool = new PrizePool(address(dripsHub), address(0));
        prizePool.setOwner(ops);

        // 2. Council sets up and manages their own ImpactPool
        impactPool = new ImpactPool(address(dripsHub), address(0));
        impactPool.setOwner(council);
    }

    /*
     * Ops can set up a stream to fund the Medical Council Multisig
     */
    function testStreamingPrize(
        uint128 initialFundingAmount,
        uint16 impactPoolFlowBasisPoints, // to stream to the Impact Council
        uint64 timePeriodInSeconds // time period to stream
    ) public {
        // Funding between $10K and $100B
        vm.assume(
            10000 ether <= initialFundingAmount &&
                initialFundingAmount <= 100000000000 ether
        );
        // Test basis points from 10% to 100%
        vm.assume(
            1000 <= impactPoolFlowBasisPoints &&
                impactPoolFlowBasisPoints <= 10000
        );
        // Test time periods from 30 days to 5 years
        vm.assume(
            30 days <= timePeriodInSeconds && timePeriodInSeconds <= 1825 days
        );

        uint128 dripPerSecond = (initialFundingAmount *
            impactPoolFlowBasisPoints) / (10000 * timePeriodInSeconds);
        uint128 totalDrip = dripPerSecond * timePeriodInSeconds;
        vm.assume(0 < dripPerSecond);

        // 3. Philanthropist (or others) fund the PrizePool through various means
        giveDaiTo(address(prizePool), initialFundingAmount);

        // 4. Ops kicks things off by streaming to the ImpactPool
        vm.startPrank(ops);
        prizePool.giveTo(
            address(impactPool),
            0,
            impactPoolFlowBasisPoints,
            timePeriodInSeconds
        );

        // 5. Ops cannot change stream until the time has gone by
        vm.expectRevert("STREAM_LOCKED");
        prizePool.giveTo(
            address(impactPool),
            0,
            impactPoolFlowBasisPoints,
            timePeriodInSeconds
        );
        vm.stopPrank();

        // 6. Council can administrate the ImpactPool by assigning Impact Points to receivers
        vm.startPrank(council);
        impactPool.updateSplits(splitsReceivers(receiver1, 7, receiver2, 3));
        vm.stopPrank();

        skip(timePeriodInSeconds);
        (uint128 collectedAmount, uint128 streamedAmount) = impactPool
            .collect();
        // Verify that the impact streamer collected no funds and streamed everything through
        console.log(collectedAmount, streamedAmount);
        // Verify that receivers have received their pro-rata share of impact streams
        console.log(dai.balanceOf(receiver1), (totalDrip * 7) / 10);
        console.log(dai.balanceOf(receiver2), (totalDrip * 3) / 10);
    }

    /*
     * Researchers can mint Hyper IP NFTs, fractionalize them, raise funds in an open-ended way,
     * and distribute their proceeds to their
     */
    function testHyperIPNFTLifecycle() public {
        // Mocking Hypercert functionality
        vm.startPrank(researcher);
        string memory hypercertName = "Psychedelic Treatment Protocol #42";
        uint256 hypercertId = hypercert.mint(bytes(hypercertName));
        assertEq(researcher, hypercert.creator(hypercertId));

        // 1. Researcher submits Hyper IP NFT for review Medical Council
        // CouncilPool.notify(hyperIPNFTID, outcomePaymentAddress);
        // 2. Researcher raises funding from Investors by minting Hyper IP NFT shares as an ERC20
        //      distributions can go through Juicebox
        // 3. Council administrates their streams to payout addresses
    }
}
// 4. Researcher creates a Hyper IP NFT

// 5. Researcher fractionalizes the Hyper IP NFT
// 6. Investor buys Hyper IP NFT shares
// 7. Evaluators can create an Evaluation NFT
// 8. Researcher submits evaluated Hyper IP NFT to Prize Pool
// 9. Council reviews Hyper IP NFT & its Evaluations
// 10. Council creates a Vault for the Hyper IP NFT
// 11. Council assigns Impact Points
// 12. Researchers & Investors stake into the IP NFT vault
