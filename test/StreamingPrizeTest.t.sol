// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "solmate/test/utils/mocks/MockERC20.sol";

import "./systems/ActorSystem.sol";
import "./systems/DripsSystem.sol";

import "src/HyperIPNFT.sol";

contract StreamingPrizeTest is ActorSystem, DripsSystem {
    PrizePool internal prizePool;
    ImpactPool internal impactPool;

    function setUp() public override(ActorSystem, DripsSystem) {
        DripsSystem.setUp();
        ActorSystem.setUp();

        // Give the Philanthropist $100M
        giveDaiTo(philanthropist, 100_000_000 ether);

        // 1. Ops sets up and manages their own PrizePool
        prizePool = new PrizePool(address(streamsHub), address(0));
        prizePool.setOwner(ops);

        // 2. Council sets up and manages their own ImpactPool
        impactPool = new ImpactPool(address(streamsHub), address(0));
        impactPool.setOwner(council);
    }

    function testStreamingPrize(
        uint8 initialPrizeFactor, // 1–255 * $1B
        uint8 months, // 6–255
        uint8 impactPoolFlowFactor, // 1–255 * 39 basis points
        uint8 donationFactor // 1–255 * $100K
    ) public {
        vm.assume(
            0 < initialPrizeFactor &&
                6 <= months &&
                0 < impactPoolFlowFactor &&
                0 < donationFactor
        );
        // Prize pools up to $225B
        uint128 initialPrizeFunding = uint128(initialPrizeFactor) *
            1_000_000_000 ether;
        // Streams up to 21.25 years long
        uint64 timePeriodInSeconds = uint64(months) * cycleSeconds;
        // Flow rates of up to 99.45%
        uint16 impactPoolFlowBasisPoints = uint16(impactPoolFlowFactor) * 39;
        // Donation of up to $25,550,000 while the stream is in progress
        uint128 donation = (uint128(donationFactor) *
            100_000 ether *
            cycleSeconds) / cycleSeconds; // normalized to cycleSeconds

        uint128 dripPerSecond = uint128(
            (initialPrizeFunding * impactPoolFlowBasisPoints) /
                (timePeriodInSeconds * 10_000)
        );
        vm.assume(0 < dripPerSecond);

        // 3. Fund the PrizePool contract
        giveDaiTo(address(prizePool), initialPrizeFunding);

        // 4. Ops sets up the stream to the ImpactPool
        vm.startPrank(ops);
        prizePool.streamTo(
            address(impactPool),
            impactPoolFlowBasisPoints,
            timePeriodInSeconds
        );
        vm.stopPrank();

        // 5. Researcher raises funds using Syndicate DAO or any other ERC20 with a transfer lock
        /// @notice MockERC20 used in place of Syndicate DAO ERC20
        MockERC20 hyperIPShares = new MockERC20(
            "Open Psilocybin Treatment #42",
            "MUSHIES",
            18
        );
        hyperIPShares.mint(researcher, 9000);
        hyperIPShares.mint(investor, 1000);
        // 6. Researcher launches their HyperIPNFT
        vm.startPrank(researcher);
        HyperIPNFT hyperIPNFT = new HyperIPNFT(
            address(streamsHub),
            address(0),
            address(hyperIPShares)
        );
        vm.stopPrank();
        // and ERC20 holders can register their shares for their stream of outcome payments
        vm.prank(researcher);
        hyperIPNFT.register();
        vm.prank(investor);
        hyperIPNFT.register();

        // 7. Council assigns Impact Points and receivers
        /// @notice receiver2 and receiver3 represent mocked hyperIPNFTs
        vm.startPrank(council);
        impactPool.setImpactSplits(
            splitsReceivers(
                address(hyperIPNFT),
                50, // Impact Points for Hyper IP NFT
                receiver2, // regular address mocking HyperIPNFT
                30, // Impact Points for receiver2
                receiver3, // regular address mocking HyperIPNFT
                20 // Impact Points for receiver3
            )
        );
        vm.stopPrank();

        // 8. After 1 month, Philanthropist starts streaming their donation to the PrizePool
        skip(cycleSeconds);
        vm.startPrank(philanthropist);
        dai.approve(address(streamsHub), donation);
        streamsHub.setDrips(
            0,
            0,
            dripsReceivers(),
            int128(donation),
            dripsReceivers(address(prizePool), donation / cycleSeconds)
        );
        vm.stopPrank();

        // Fast forward to the end of the stream
        skip(timePeriodInSeconds - cycleSeconds + 1);

        // Verify the PrizePool's collection and streaming of the donation
        (uint128 prizeCollections, uint128 prizeStreamed) = prizePool.collect();
        assertStreamEq(
            prizeCollections,
            (donation * (10_000 - impactPoolFlowBasisPoints)) / 10_000
        );
        assertStreamEq(
            prizeStreamed,
            (donation * impactPoolFlowBasisPoints) / 10_000
        );
        // Verify the Impact Pool's colletion and streaming of outcome payments
        (uint128 collected, uint128 outcomePaymentsStreamed) = impactPool
            .collect();
        assertEq(collected, 0);
        uint128 outcomePaymentsReceived = dripPerSecond *
            timePeriodInSeconds +
            (donation * impactPoolFlowBasisPoints) /
            10_000;
        assertStreamEq(outcomePaymentsStreamed, outcomePaymentsReceived);
        // Verify that receivers can collect their pro-rata share of outcome payments
        (uint128 r2payout, ) = streamsHub.collect(receiver2, splitsReceivers());
        assertStreamEq(r2payout, (outcomePaymentsStreamed * 3) / 10);
        (uint128 r3payout, ) = streamsHub.collect(receiver3, splitsReceivers());
        assertStreamEq(r3payout, (outcomePaymentsStreamed * 2) / 10);
        // Verify that Hyper IP NFT shareholders received their outcome payments
        (uint128 collectedIPPayments, uint128 streamedIPPayments) = hyperIPNFT
            .collect();
        assertEq(collectedIPPayments, 0);
        assertStreamEq(streamedIPPayments, (outcomePaymentsStreamed * 5) / 10);
        // Verify that the researcher received their share of outcome payments
        (uint128 researcherPayout, ) = streamsHub.collect(
            researcher,
            splitsReceivers()
        );
        assertStreamEq(researcherPayout, (outcomePaymentsStreamed * 45) / 100);
        // Verify that the researcher received their share of outcome payments
        (uint128 investorPayout, ) = streamsHub.collect(
            investor,
            splitsReceivers()
        );
        assertStreamEq(investorPayout, (outcomePaymentsStreamed * 5) / 100);
    }

    function testHyperIPNFTRegistration(
        uint16 researcherShares,
        uint16 r1shares,
        uint16 r2shares,
        uint16 r3shares
    ) public returns (HyperIPNFT hyperIPNFT) {
        vm.assume(
            2000 <= researcherShares &&
                2000 <= r1shares &&
                2000 <= r2shares &&
                2000 <= r3shares
        );

        MockERC20 shares = new MockERC20(
            "Open Psilocybin Treatment #42",
            "MUSHIES",
            18
        );
        shares.mint(researcher, researcherShares);
        shares.mint(receiver1, r1shares);
        shares.mint(receiver2, r2shares);
        shares.mint(receiver3, r3shares);

        hyperIPNFT = new HyperIPNFT(
            address(streamsHub),
            address(0),
            address(shares)
        );

        vm.prank(researcher);
        hyperIPNFT.register();
        vm.prank(receiver1);
        hyperIPNFT.register();
        vm.prank(receiver2);
        hyperIPNFT.register();
        vm.prank(receiver3);
        hyperIPNFT.register();
    }

    function testOpsCannotChangeStreamWhileLocked(uint8 factor) public {
        vm.assume(0 < factor);
        uint64 timelock = uint64(factor) * 24 hours;

        giveDaiTo(address(prizePool), 1_000_000 ether); // $1M

        vm.startPrank(ops);
        prizePool.streamTo(address(impactPool), 1000, timelock);

        vm.expectRevert("STREAM_LOCKED");
        prizePool.streamTo(address(impactPool), 1000, timelock);

        skip(timelock + 5 minutes);
        prizePool.streamTo(address(impactPool), 1000, timelock);
        vm.stopPrank();
    }
}
