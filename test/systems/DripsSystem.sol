// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "drips-contracts/IDai.sol";
import "drips-contracts/ERC20DripsHub.sol";

import "src/ImpactSplitter.sol";
import "src/PrizePool.sol";

abstract contract DripsSystem is Test {
    ERC20DripsHub internal streamsHub;
    address internal streamsHubAddress;
    IDai internal dai;
    uint64 internal cycleSeconds;

    function setUp() public virtual {
        vm.createSelectFork("mainnet", 15600000);

        streamsHub = ERC20DripsHub(0x73043143e0A6418cc45d82D4505B096b802FD365);
        streamsHubAddress = address(streamsHub);
        vm.label(address(streamsHub), "DaiDripsHub");

        dai = IDai(address(streamsHub.erc20()));
        vm.label(address(dai), "Dai");

        cycleSeconds = streamsHub.cycleSecs();
        skipToCycleEnd(); // to synchronize with Drips
    }

    function giveDaiTo(address to, uint256 give) internal {
        deal(address(dai), to, give, false);
    }

    function assertStreamEq(uint256 a, uint256 b) internal {
        assertApproxEqRel(a, b, 1.0e13); // 0.001% tolerance for integer rounding errors
    }

    // ============================================================
    // ===================== DRIPS HELPERS ========================
    // ============================================================
    function skipToCycleEnd() internal {
        skip(cycleSeconds - (block.timestamp % cycleSeconds));
    }

    function dripsReceivers()
        internal
        pure
        returns (DripsReceiver[] memory list)
    {
        list = new DripsReceiver[](0);
    }

    function dripsReceivers(address user, uint128 amtPerSec)
        internal
        pure
        returns (DripsReceiver[] memory list)
    {
        list = new DripsReceiver[](1);
        list[0] = DripsReceiver(user, amtPerSec);
    }

    function dripsReceivers(
        address user1,
        uint128 amtPerSec1,
        address user2,
        uint128 amtPerSec2
    ) internal pure returns (DripsReceiver[] memory list) {
        list = new DripsReceiver[](2);
        if (user1 > user2) {
            (user1, user2) = (user2, user1);
            (amtPerSec1, amtPerSec2) = (amtPerSec2, amtPerSec1);
        }
        list[0] = DripsReceiver(user1, amtPerSec1);
        list[1] = DripsReceiver(user2, amtPerSec2);
    }

    function splitsReceivers()
        internal
        pure
        returns (SplitsReceiver[] memory list)
    {
        list = new SplitsReceiver[](0);
    }

    function splitsReceivers(address user, uint32 weight)
        internal
        pure
        returns (SplitsReceiver[] memory list)
    {
        list = new SplitsReceiver[](1);
        list[0] = SplitsReceiver(user, weight);
    }

    function splitsReceivers(
        address user1,
        uint32 weight1,
        address user2,
        uint32 weight2
    ) internal pure returns (SplitsReceiver[] memory list) {
        list = new SplitsReceiver[](2);
        if (user1 > user2) {
            (user1, user2) = (user2, user1);
            (weight1, weight2) = (weight2, weight1);
        }
        list[0] = SplitsReceiver(user1, weight1);
        list[1] = SplitsReceiver(user2, weight2);
    }

    function splitsReceivers(
        address user1,
        uint32 weight1,
        address user2,
        uint32 weight2,
        address user3,
        uint32 weight3
    ) internal pure returns (SplitsReceiver[] memory list) {
        list = new SplitsReceiver[](3);
        if (user1 > user2) {
            (user1, user2) = (user2, user1);
            (weight1, weight2) = (weight2, weight1);
        }
        if (user2 > user3) {
            (user2, user3) = (user3, user2);
            (weight2, weight3) = (weight3, weight2);
        }
        if (user1 > user2) {
            (user1, user2) = (user2, user1);
            (weight1, weight2) = (weight2, weight1);
        }
        list[0] = SplitsReceiver(user1, weight1);
        list[1] = SplitsReceiver(user2, weight2);
        list[2] = SplitsReceiver(user3, weight3);
    }
}
