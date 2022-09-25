// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import "juice-contracts-v3/JBController.sol";
import "juice-contracts-v3/JBETHPaymentTerminal.sol";

abstract contract JuiceboxSystem is Test {
    address internal constant ETH =
        address(0x000000000000000000000000000000000000EEEe);

    JBController internal controller;
    JBETHPaymentTerminal internal ethHandler;

    // Pre-allocate constant variables across pool deployments
    JBFundAccessConstraints[] internal fundAccessConstraints;
    IJBPaymentTerminal[] internal terminals;

    function setUp() public virtual {
        // Run against the latest Juicebox contracts on Goerli, cached to block 7642000
        vm.createSelectFork("goerli", 7642000);

        controller = JBController(0x7Cb86D43B665196BC719b6974D320bf674AFb395);
        vm.label(address(controller), "Controller");
        ethHandler =
            JBETHPaymentTerminal(0x55d4dfb578daA4d60380995ffF7a706471d7c719);
        vm.label(address(ethHandler), "ETHHandler");

        terminals = new IJBPaymentTerminal[](1);
        terminals[0] = ethHandler;
    }

    function pay(
        uint256 poolId,
        uint256 amount,
        address token,
        uint256 expectedTokens,
        string memory memo
    )
        public
        payable
        returns (uint256 tokensReceived)
    {
        tokensReceived = ethHandler.pay{value: msg.value}(
            poolId,
            amount,
            token,
            msg.sender,
            expectedTokens,
            false,
            memo,
            "<metadata>"
        );
    }

    function createPrizePool(
        uint256 prizePoolTokensPerETH,
        uint256 distributionPoolProjectId
    )
        internal
        returns (uint256 poolId, uint256 nextPoolId)
    {
        JBFundingCycleData memory fundingCycleConfig = JBFundingCycleData({
            duration: 0,
            weight: prizePoolTokensPerETH,
            discountRate: 0,
            ballot: IJBFundingCycleBallot(address(0))
        });
        JBFundingCycleMetadata memory fundingCycleOptions =
        JBFundingCycleMetadata({
            global: JBGlobalFundingCycleMetadata({
                allowSetTerminals: false,
                allowSetController: false,
                pauseTransfers: false
            }),
            reservedRate: 0,
            redemptionRate: 0,
            ballotRedemptionRate: 0,
            pausePay: false,
            pauseDistributions: false,
            pauseRedeem: false,
            pauseBurn: false,
            allowMinting: false,
            allowTerminalMigration: true,
            allowControllerMigration: true,
            holdFees: false,
            preferClaimedTokenOverride: false,
            useTotalOverflowForRedemptions: false,
            useDataSourceForPay: false,
            useDataSourceForRedeem: false,
            dataSource: address(0),
            metadata: 0
        });
        JBGroupedSplits[] memory groupedSplits;

        nextPoolId = controller.launchProjectFor(
            msg.sender,
            JBProjectMetadata({content: "<IPFS hash>", domain: 0}),
            fundingCycleConfig,
            fundingCycleOptions,
            block.timestamp + 365 days,
            groupedSplits,
            fundAccessConstraints,
            terminals,
            "Prize Pool"
        );

        JBSplit[] memory splits = new JBSplit[](2);
        splits[0] = JBSplit({
            preferClaimed: false,
            preferAddToBalance: true,
            percent: JBConstants.SPLITS_TOTAL_PERCENT * 2 / 10, // 20%
            projectId: distributionPoolProjectId,
            beneficiary: payable(address(0)),
            lockedUntil: block.timestamp + 365 days,
            allocator: IJBSplitAllocator(address(0))
        });
        splits[1] = JBSplit({
            preferClaimed: false,
            preferAddToBalance: true,
            percent: JBConstants.SPLITS_TOTAL_PERCENT * 8 / 10, // 80%
            projectId: nextPoolId,
            beneficiary: payable(address(0)),
            lockedUntil: block.timestamp + 365 days,
            allocator: IJBSplitAllocator(address(0))
        });

        groupedSplits = new JBGroupedSplits[](1);
        groupedSplits[0] = JBGroupedSplits({group: 1, splits: splits});

        poolId = controller.launchProjectFor(
            msg.sender,
            JBProjectMetadata({content: "<IPFS hash>", domain: 0}),
            fundingCycleConfig,
            fundingCycleOptions,
            block.timestamp,
            groupedSplits,
            fundAccessConstraints,
            terminals,
            "Prize Pool"
        );
    }

    function createDistributionPool() internal returns (uint256 poolId) {
        JBGroupedSplits[] memory groupedSplits;

        poolId = controller.launchProjectFor(
            msg.sender,
            JBProjectMetadata({content: "<IPFS hash>", domain: 0}),
            JBFundingCycleData({
                duration: 0,
                weight: 0, // no tokens
                discountRate: 0,
                ballot: IJBFundingCycleBallot(address(0))
            }),
            JBFundingCycleMetadata({
                global: JBGlobalFundingCycleMetadata({
                    allowSetTerminals: false,
                    allowSetController: false,
                    pauseTransfers: false
                }),
                reservedRate: 0,
                redemptionRate: 0,
                ballotRedemptionRate: 0,
                pausePay: false,
                pauseDistributions: false,
                pauseRedeem: false,
                pauseBurn: false,
                allowMinting: false,
                allowTerminalMigration: true,
                allowControllerMigration: true,
                holdFees: false,
                preferClaimedTokenOverride: false,
                useTotalOverflowForRedemptions: false,
                useDataSourceForPay: false,
                useDataSourceForRedeem: false,
                dataSource: address(0),
                metadata: 0
            }),
            block.timestamp,
            groupedSplits,
            fundAccessConstraints,
            terminals,
            "Distribution Pool"
        );
    }

    function createHyperIPNFTPool(uint256 hypercertTokensPerETH)
        internal
        returns (uint256 poolId)
    {
        JBGroupedSplits[] memory groupedSplits;

        poolId = controller.launchProjectFor(
            msg.sender,
            JBProjectMetadata({content: "<IPFS hash>", domain: 0}),
            JBFundingCycleData({
                duration: 0,
                weight: hypercertTokensPerETH,
                discountRate: 0,
                ballot: IJBFundingCycleBallot(address(0))
            }),
            JBFundingCycleMetadata({
                global: JBGlobalFundingCycleMetadata({
                    allowSetTerminals: false,
                    allowSetController: false,
                    pauseTransfers: false
                }),
                reservedRate: 0,
                redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
                ballotRedemptionRate: 0,
                pausePay: false,
                pauseDistributions: false,
                pauseRedeem: false,
                pauseBurn: false,
                allowMinting: true,
                allowTerminalMigration: true,
                allowControllerMigration: true,
                holdFees: false,
                preferClaimedTokenOverride: false,
                useTotalOverflowForRedemptions: true,
                useDataSourceForPay: false,
                useDataSourceForRedeem: false,
                dataSource: address(0),
                metadata: 0
            }),
            block.timestamp,
            groupedSplits,
            fundAccessConstraints,
            terminals,
            "Hyper IP NFT"
        );
    }
}
