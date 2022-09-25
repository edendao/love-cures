// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "./systems/ActorSystem.sol";
import "./systems/HypercertSystem.sol";
import "./systems/DripsSystem.sol";

contract DripsPrizeTest is ActorSystem, HypercertSystem, DripsSystem {
    PrizeStreamer internal prizeStreamer;
    ImpactStreamer internal impactStreamer;
    uint128 internal constant initialFundingAmount = 10000000.0e18; // $10M

    function setUp()
        public
        override (ActorSystem, HypercertSystem, DripsSystem)
    {
        DripsSystem.setUp();
        HypercertSystem.setUp();
        ActorSystem.setUp();

        giveDaiTo(philanthropist, initialFundingAmount);

        // 1. Ops sets up and manages their own PrizeStreamer
        vm.startPrank(ops);
        prizeStreamer = new PrizeStreamer(address(dripsHub), address(0));
        vm.stopPrank();

        // 2. Council sets up and manages their own ImpactStreamer
        vm.startPrank(council);
        impactStreamer = new ImpactStreamer(address(dripsHub), address(0));
        vm.stopPrank();

        // 3. Philanthropist (or others) fund the PrizeStreamer through various means
        vm.startPrank(philanthropist);
        dai.transfer(address(prizeStreamer), initialFundingAmount);
        vm.stopPrank();
    }

    /* 
     * Ops can set up a stream to fund the Medical Council Multisig
     */
    function testStreamingPrizeFund(
        uint32 basisPoints,
        uint64 timePeriodInSeconds
    )
        public
    {
        uint128 totalDripAmount = initialFundingAmount * basisPoints / 10000;
        vm.assume(
            24 hours < timePeriodInSeconds && 0 < totalDripAmount / timePeriodInSeconds
        );

        // 4. Ops kicks things off by streaming to the ImpactStreamer
        vm.startPrank(ops);
        prizeStreamer.streamTo(
            address(impactStreamer), basisPoints, timePeriodInSeconds
        );

        // 5. Ops cannot change stream until the time has gone by
        vm.expectRevert("STREAM_LOCKED");
        prizeStreamer.streamTo(
            address(impactStreamer), basisPoints, timePeriodInSeconds
        );
        vm.stopPrank();

        skip(timePeriodInSeconds);
        collect(address(impactStreamer), totalDripAmount);
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
