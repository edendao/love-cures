// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "./systems/ActorSystem.sol";
import "./systems/StreamingSystem.sol";

contract StreamingPrizeTest is ActorSystem, StreamingSystem {
    PrizePool internal prizePool;
    ImpactPool internal impactPool;

    function setUp() public override(ActorSystem, StreamingSystem) {
        StreamingSystem.setUp();
        ActorSystem.setUp();

        // Give the Philanthropist $10M
        giveDaiTo(philanthropist, 10_000_000 ether);

        // 1. Ops sets up and manages their own PrizePool
        prizePool = new PrizePool(address(streamsHub), address(0));
        prizePool.setOwner(ops);

        // 2. Council sets up and manages their own ImpactPool
        impactPool = new ImpactPool(address(streamsHub), address(0));
        impactPool.setOwner(council);
    }

    /*
     * Test 16M+ combinations of factors for streaming funds
     * from the Prize Pool to Impactful Research.
     */
    function testStreamingPrize(
        uint8 initialPrizeFactor, // 1–255
        uint8 cycles, // 6–255
        uint8 impactPoolFlowFactor, // 1–255
        uint8 donationFactor // 1–255
    ) public {
        vm.assume(
            0 < initialPrizeFactor &&
                6 <= cycles &&
                0 < impactPoolFlowFactor &&
                0 < donationFactor
        );
        // Prize pools up to $225B
        uint128 initialPrizeFunding = uint128(initialPrizeFactor) *
            1_000_000_000 ether;
        // Streams up to 21.25 years long
        uint64 timePeriodInSeconds = uint64(cycles) * cycleSeconds;
        // Flow rates of up to 99.45%
        uint16 impactPoolFlowBasisPoints = uint16(impactPoolFlowFactor) * 39;
        // Donation of up to $2,550,000 while the stream is in progress, normalized to cycleSeconds
        uint128 donation = (uint128(donationFactor) *
            10_000 ether *
            cycleSeconds) / cycleSeconds;

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

        // 5. Council can administrate the ImpactPool by assigning Impact Points to receivers
        vm.startPrank(council);
        impactPool.updateSplits(
            splitsReceivers(receiver1, 50, receiver2, 30, receiver3, 20)
        );
        vm.stopPrank();

        // 6. After 1 month, Philanthropist starts streaming money to the PrizePool
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

        skip(timePeriodInSeconds + 1);

        (uint128 prizeCollections, uint128 prizeStreamed) = prizePool.collect();
        assertApproxEq(
            prizeCollections,
            (donation * (10_000 - impactPoolFlowBasisPoints)) / 10_000
        );
        assertApproxEq(
            prizeStreamed,
            (donation * impactPoolFlowBasisPoints) / 10_000
        );
        (uint128 collected, uint128 streamed) = impactPool.collect();
        // Verify that the Prize Pool collected its share of the donation
        assertEq(collected, 0);
        // Verify that the Prize Pool streamed the rest
        uint128 totalStreamed = dripPerSecond *
            timePeriodInSeconds +
            (donation * impactPoolFlowBasisPoints) /
            10_000;
        assertApproxEq(streamed, totalStreamed);
        // Verify that receivers can collect their pro-rata share of outcome payments
        (uint128 r1collected, ) = streamsHub.collect(
            receiver1,
            splitsReceivers()
        );
        assertApproxEq(r1collected, (totalStreamed * 5) / 10);
        (uint128 r2collected, ) = streamsHub.collect(
            receiver2,
            splitsReceivers()
        );
        assertApproxEq(r2collected, (totalStreamed * 3) / 10);
        (uint128 r3collected, ) = streamsHub.collect(
            receiver3,
            splitsReceivers()
        );
        assertApproxEq(r3collected, (totalStreamed * 2) / 10);
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
