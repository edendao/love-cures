// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "solmate/test/utils/mocks/MockERC20.sol";

import "./systems/ActorSystem.sol";
import "./systems/DripsSystem.sol";

import "src/ImpactProtocolVault.sol";
import "src/ImpactProtocolPool.sol";

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

    function testDemoStreamingPrize() public {
        testFuzzStreamingPrize({
            initialPrizeFactor: 10, // $10M initial prize pool
            months: 12,
            impactPoolFlowFactor: 51, // 19.89%
            donationFactor: 10 // $1M donation
        });
    }

    function testFuzzStreamingPrize(
        uint8 initialPrizeFactor, // 1–255 * $1M
        uint8 months, // 6–255
        uint8 impactPoolFlowFactor, // 1–255 * 39 basis points
        uint8 donationFactor // 1–255 * $100K
    ) public {
        vm.assume(
            0 < initialPrizeFactor &&
                3 <= months &&
                0 < impactPoolFlowFactor &&
                0 < donationFactor
        );
        // Prize pools up to $225M
        uint128 initialPrizeFunding = uint128(initialPrizeFactor) *
            1_000_000 ether;
        // Streams up to 21.25 years long
        uint64 timePeriodInSeconds = uint64(months) * cycleSeconds;
        // Flow rates of 0.39–99.45%
        uint16 impactPoolFlowBasisPoints = uint16(impactPoolFlowFactor) * 39;
        // Donation of up to $25,550,000 while the stream is in progress
        uint128 donation = (uint128(donationFactor) *
            100_000 ether *
            cycleSeconds) / cycleSeconds; // normalized to cycleSeconds

        uint128 flowPerSecond = uint128(
            (initialPrizeFunding * impactPoolFlowBasisPoints) /
                (timePeriodInSeconds * 10_000)
        );
        vm.assume(0 < flowPerSecond);

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

        // 5. Researcher raises funds using Syndicate DAO or any other ERC20 platform
        /// @notice MockERC20 represents the token that fractionalize their Hyper IP NFT
        MockERC20 ipShares = new MockERC20(
            "Open Psilocybin Treatment #42",
            "SHROOMS",
            18
        );
        uint256 researcherShares = 1000;
        uint256 investorShares = 9000;
        ipShares.mint(researcher, researcherShares);
        ipShares.mint(investor, investorShares);

        /// 6a. An Impact Protocol Pool allows shareholders to receive a share of
        /// 6b. An Impact Protocol Vault allows shareholders to stake their IP shares
        /// A stake can be redeemed before maturity for a pro-rata share of the accumulated
        /// payments at anytime. Redeeming your share early before all funds have been streamed
        /// gives you liquidity but no claim on future streamed funds.
        ///
        /// This acts akin to a tradeable bond and enables price discovery in secondary markets.
        ImpactProtocolVault ipVault = new ImpactProtocolVault(
            address(streamsHub),
            address(ipShares),
            "Open Psilocybin Treatment #42 Impact Protocol Vault",
            "ipSHROOMS"
        );
        vm.label(address(ipVault), "ImpactProtocolVault");
        // Researcher stakes their tokens in the vault
        vm.startPrank(researcher);
        ipShares.approve(address(ipVault), researcherShares);
        ipVault.deposit(researcherShares, researcher);
        assertEq(ipVault.balanceOf(researcher), researcherShares);
        vm.stopPrank();
        // Investor stakes their token in the vault
        vm.startPrank(investor);
        ipShares.approve(address(ipVault), investorShares);
        ipVault.deposit(investorShares, investor);
        assertEq(ipVault.balanceOf(investor), investorShares);
        vm.stopPrank();

        // 7. Council assigns Impact Points and receivers
        /// @notice receiver2 and receiver3 represent mocked ipPools
        vm.startPrank(council);
        impactPool.setImpactSplits(
            splitsReceivers(
                address(ipVault),
                50, // Impact Points for Hyper IP NFT
                receiver2, // stub for a ImpactProtocolPool for DMT, for example
                30, // Impact Points for receiver2
                receiver3, // stub for a ImpactProtocolPool for LSD, for example
                20 // Impact Points for receiver3
            )
        );
        vm.stopPrank();

        // 8. After 1 month, Philanthropist streams donation over 2 months to the PrizePool
        //    to boost outcome payments
        skip(cycleSeconds);
        vm.startPrank(philanthropist);
        dai.approve(address(streamsHub), donation);
        streamsHub.setDrips(
            0,
            0,
            dripsReceivers(),
            int128(donation),
            dripsReceivers(address(prizePool), donation / cycleSeconds / 2)
        );
        vm.stopPrank();

        // Fast forward to the end of all streams
        skip(timePeriodInSeconds - cycleSeconds + 1);

        // Verify the PrizePool's collection and streaming of the donation
        (uint128 prizeHoldings, uint128 prizeFlow) = prizePool.collect();
        assertStreamEq(
            prizeHoldings,
            (donation * (10_000 - impactPoolFlowBasisPoints)) / 10_000
        );
        assertStreamEq(
            prizeFlow,
            (donation * impactPoolFlowBasisPoints) / 10_000
        );
        // Verify the Impact Pool's colletion and streaming of outcome payments
        (uint128 impactHoldings, uint128 outcomePaymentsTotalFlow) = impactPool
            .collect();
        assertEq(impactHoldings, 0); // Impact Pool should not hold any funds
        uint128 expectedTotalFlowOfOutcomePayments = flowPerSecond *
            timePeriodInSeconds +
            (donation * impactPoolFlowBasisPoints) /
            10_000;
        assertStreamEq(
            outcomePaymentsTotalFlow,
            expectedTotalFlowOfOutcomePayments
        );
        // Verify that Hyper IP NFT shareholders received their outcome payments
        uint128 ipVaultHoldings = ipVault.collect();
        assertStreamEq(ipVaultHoldings, (outcomePaymentsTotalFlow * 5) / 10);
        // Verify that the researcher received their share of outcome payments
        assertStreamEq(
            ipVault.previewRedeem(researcherShares),
            (ipVaultHoldings * researcherShares) / 10_000
        );
        // Verify that the investor received their share of outcome payments
        assertStreamEq(
            ipVault.previewRedeem(investorShares),
            (ipVaultHoldings * investorShares) / 10_000
        );
        // Verify that receivers can collect their pro-rata share of outcome payments
        (uint128 r2payout, ) = streamsHub.collect(receiver2, splitsReceivers());
        assertStreamEq(r2payout, (outcomePaymentsTotalFlow * 3) / 10);
        (uint128 r3payout, ) = streamsHub.collect(receiver3, splitsReceivers());
        assertStreamEq(r3payout, (outcomePaymentsTotalFlow * 2) / 10);
    }

    function xtestImpactProtocolPoolRegistration(
        uint16 researcherShares,
        uint16 r1ipShares,
        uint16 r2ipShares,
        uint16 r3ipShares
    ) public {
        vm.assume(
            2000 <= researcherShares &&
                2000 <= r1ipShares &&
                2000 <= r2ipShares &&
                2000 <= r3ipShares
        );

        MockERC20 ipShares = new MockERC20(
            "Open Psilocybin Treatment #42",
            "SHROOMS",
            18
        );
        ipShares.mint(researcher, researcherShares);
        ipShares.mint(receiver1, r1ipShares);
        ipShares.mint(receiver2, r2ipShares);
        ipShares.mint(receiver3, r3ipShares);

        ImpactProtocolPool ipPool = new ImpactProtocolPool(
            address(streamsHub),
            address(0),
            address(ipShares)
        );

        vm.prank(researcher);
        ipPool.register();
        vm.prank(receiver1);
        ipPool.register();
        vm.prank(receiver2);
        ipPool.register();
        vm.prank(receiver3);
        ipPool.register();
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
