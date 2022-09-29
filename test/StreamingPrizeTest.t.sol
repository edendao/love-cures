// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "solmate/test/utils/mocks/MockERC20.sol";

import "./systems/ActorSystem.sol";
import "./systems/DripsSystem.sol";

import "src/ImpactProtocolVault.sol";
import "src/ImpactProtocolSplitter.sol";

contract StreamingPrizeTest is ActorSystem, DripsSystem {
    function setUp() public override(ActorSystem, DripsSystem) {
        DripsSystem.setUp();
        ActorSystem.setUp();
    }

    function testOpsCannotChangeStreamWhileLocked(uint8 factor) public {
        vm.assume(0 < factor);
        uint64 timelock = uint64(factor) * 24 hours;

        (
            PrizePool prize,
            ImpactSplitter splitter
        ) = _createPrizePoolAndImpactSplitter();

        giveDaiTo(address(prize), 1_000_000 ether); // $1M

        vm.startPrank(ops);
        prize.streamTo(address(splitter), 1000, timelock);

        vm.expectRevert("STREAM_LOCKED");
        prize.streamTo(address(splitter), 1000, timelock);

        skip(timelock + 5 minutes);
        prize.streamTo(address(splitter), 1000, timelock);
        vm.stopPrank();
    }

    function _createPrizePoolAndImpactSplitter()
        internal
        returns (PrizePool prize, ImpactSplitter splitter)
    {
        // 1. Ops sets up and manages their own PrizePool
        prize = new PrizePool(streamsHubAddress, address(0));
        prize.setOwner(ops);

        // 2. Committee sets up and manages their own ImpactSplitter
        splitter = new ImpactSplitter(streamsHubAddress, address(0));
        splitter.setOwner(committee);
    }

    function _createImpactProtocolVaultAndStake(
        uint256 researcherShares,
        uint256 investorShares
    ) internal returns (MockERC20 ipShares, ImpactProtocolVault vault) {
        ipShares = new MockERC20(
            "Open Psilocybin Treatment #42",
            "SHROOMS",
            18
        );
        ipShares.mint(researcher, researcherShares);
        ipShares.mint(investor, investorShares);

        vault = new ImpactProtocolVault(
            streamsHubAddress,
            address(ipShares),
            "Open Psilocybin Treatment #42 Impact Protocol Vault",
            "ipSHROOMS"
        );
        address vaultAddress = address(vault);
        vm.label(vaultAddress, "ImpactProtocolVault");
        // Researcher stakes their tokens in the vault
        vm.startPrank(researcher);
        ipShares.approve(vaultAddress, researcherShares);
        vault.deposit(researcherShares, researcher);
        assertEq(vault.balanceOf(researcher), researcherShares);
        vm.stopPrank();
        // Investor stakes their token in the vault
        vm.startPrank(investor);
        ipShares.approve(vaultAddress, investorShares);
        vault.deposit(investorShares, investor);
        assertEq(vault.balanceOf(investor), investorShares);
        vm.stopPrank();
    }

    function testPrizePoolCorrectnessGoToMarket() public {
        (
            PrizePool openLongevityPrizePool,
            ImpactSplitter openLongevityImpactSplitter
        ) = _createPrizePoolAndImpactSplitter();

        _verifyFlows({
            prizePool: openLongevityPrizePool,
            impactSplitter: openLongevityImpactSplitter,
            timePeriodInSeconds: 365 days,
            // $10M
            prizePoolFunding: 10_000_000 ether,
            // 20% annual flow
            flowToImpactBasisPoints: 2_000,
            // Surprise $250K donation during over the year from another source
            donation: 250_000 ether,
            researcherShares: 1000,
            investorShares: 9000
        });
    }

    function testPrizePoolCorrectnessMillions(
        uint8 initialPrizeFactor,
        uint8 months,
        uint8 flowToImpactFactor,
        uint8 donationFactor
    ) public {
        vm.assume(
            0 < initialPrizeFactor &&
                3 <= months &&
                0 < flowToImpactFactor &&
                0 < donationFactor
        );

        (
            PrizePool daoPrizePool,
            ImpactSplitter daoImpactSplitter
        ) = _createPrizePoolAndImpactSplitter();

        _verifyFlows({
            prizePool: daoPrizePool,
            impactSplitter: daoImpactSplitter,
            // 3 months–21.25 years
            timePeriodInSeconds: uint64(months) * cycleSeconds,
            // $1M–$255M
            prizePoolFunding: uint128(initialPrizeFactor) * 1_000_000 ether,
            // 0.25%–56.25%
            flowToImpactBasisPoints: uint16(flowToImpactFactor) * 25,
            // $100K–$25.5M
            donation: uint128(donationFactor) * 100_000 ether,
            researcherShares: 1000,
            investorShares: 9000
        });
    }

    function testPrizePoolCorrectnessBillions(
        uint8 initialPrizeFactor,
        uint8 months,
        uint8 flowToImpactFactor,
        uint8 donationFactor
    ) public {
        vm.assume(
            0 < initialPrizeFactor &&
                3 <= months &&
                0 < flowToImpactFactor &&
                0 < donationFactor
        );

        (
            PrizePool daoPrizePool,
            ImpactSplitter daoImpactSplitter
        ) = _createPrizePoolAndImpactSplitter();

        _verifyFlows({
            prizePool: daoPrizePool,
            impactSplitter: daoImpactSplitter,
            // 3 months–21 years & 4 months
            timePeriodInSeconds: uint64(months) * cycleSeconds,
            // $1B–$255B
            prizePoolFunding: uint128(initialPrizeFactor) * 1_000_000_000 ether,
            // 0.25%–56.25%
            flowToImpactBasisPoints: uint16(flowToImpactFactor) * 25,
            // $1M–$255M
            donation: uint128(donationFactor) * 1_000_000 ether,
            researcherShares: 1000,
            investorShares: 9000
        });
    }

    function _verifyFlows(
        PrizePool prizePool,
        ImpactSplitter impactSplitter,
        uint128 prizePoolFunding,
        uint16 flowToImpactBasisPoints,
        uint128 donation,
        uint64 timePeriodInSeconds,
        uint256 researcherShares,
        uint256 investorShares
    ) internal {
        uint128 expectedTotalFlowOfOutcomePayments;
        address targetAddress;
        // to save on stack space
        {
            uint128 flowPerSecond = uint128(
                (prizePoolFunding * flowToImpactBasisPoints) /
                    (timePeriodInSeconds * 10_000)
            );
            vm.assume(0 < flowPerSecond);

            donation = (donation / cycleSeconds) * cycleSeconds; // normalize
            expectedTotalFlowOfOutcomePayments =
                flowPerSecond *
                timePeriodInSeconds +
                (donation * flowToImpactBasisPoints) /
                10_000;

            // 3. Fund the PrizePool contract and the Philanthropist's wallet
            giveDaiTo(address(prizePool), prizePoolFunding);
            giveDaiTo(philanthropist, donation);
        }

        // 4. Ops sets up the stream to the ImpactSplitter
        targetAddress = address(impactSplitter);
        vm.prank(ops);
        prizePool.streamTo(
            targetAddress,
            flowToImpactBasisPoints,
            timePeriodInSeconds
        );

        /// 5. Researcher raises funds using Syndicate DAO or any other ERC20 platform
        /// 6. An Impact Protocol Vault allows shareholders to stake their IP shares
        /// A stake can be redeemed before maturity for a pro-rata share of the accumulated
        /// payments at anytime. Redeeming your share early before all funds have been streamed
        /// gives you liquidity but no claim on future streamed funds.
        ///
        /// This acts like a tradeable bond and enables price discovery in secondary markets.
        (, ImpactProtocolVault ipVault) = _createImpactProtocolVaultAndStake(
            researcherShares,
            investorShares
        );

        // 7. Committee assigns Impact Points and receivers
        /// @notice receiver2 and receiver3 represent mocked ipSplitters
        vm.startPrank(committee);
        targetAddress = address(ipVault);
        impactSplitter.setImpactSplits(
            splitsReceivers(
                targetAddress,
                50, // Impact Points for Hyper IP NFT
                receiver2, // stub for a ImpactProtocolSplitter for DMT, for example
                30, // Impact Points for receiver2
                receiver3, // stub for a ImpactProtocolSplitter for LSD, for example
                20 // Impact Points for receiver3
            )
        );
        vm.stopPrank();

        // 8. After 1 month, Philanthropist streams donation over 2 months to the PrizePool
        //    to boost outcome payments
        skip(cycleSeconds);
        vm.startPrank(philanthropist);
        dai.approve(streamsHubAddress, donation);
        targetAddress = address(prizePool);
        streamsHub.setDrips(
            0,
            0,
            dripsReceivers(),
            int128(donation),
            dripsReceivers(targetAddress, donation / cycleSeconds / 2)
        );
        vm.stopPrank();

        // Fast forward to the end of all streams
        skip(timePeriodInSeconds + 1);

        // To save on stack space
        uint128 holdings;
        uint128 flow;

        // Verify the PrizePool's collection and streaming of the donation
        (holdings, flow) = prizePool.collect();
        assertStreamEq(
            holdings,
            (donation * (10_000 - flowToImpactBasisPoints)) / 10_000
        );
        assertStreamEq(flow, (donation * flowToImpactBasisPoints) / 10_000);
        // Verify the Impact Pool's colletion and streaming of outcome payments
        (holdings, flow) = impactSplitter.collect();
        assertEq(holdings, 0); // Impact Pool should not hold any funds
        assertStreamEq(flow, expectedTotalFlowOfOutcomePayments);
        // Verify that Vault shareholders can redeem their share of outcome payments
        holdings = ipVault.collect();
        assertStreamEq(holdings, (expectedTotalFlowOfOutcomePayments * 5) / 10);
        // Verify that the researcher received their share of outcome payments
        assertStreamEq(
            ipVault.previewRedeem(researcherShares),
            (holdings * researcherShares) / 10_000
        );
        // Verify that the investor received their share of outcome payments
        assertStreamEq(
            ipVault.previewRedeem(investorShares),
            (holdings * investorShares) / 10_000
        );
        // Verify that receivers can collect their pro-rata share of outcome payments
        (holdings, ) = streamsHub.collect(receiver2, splitsReceivers());
        assertStreamEq(holdings, (expectedTotalFlowOfOutcomePayments * 3) / 10);
        (holdings, ) = streamsHub.collect(receiver3, splitsReceivers());
        assertStreamEq(holdings, (expectedTotalFlowOfOutcomePayments * 2) / 10);
    }
}
