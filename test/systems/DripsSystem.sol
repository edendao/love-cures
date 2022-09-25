// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "drips-contracts/IDai.sol";
import "drips-contracts/ERC20DripsHub.sol";

import "src/ImpactPool.sol";
import "src/PrizePool.sol";

abstract contract DripsSystem is Test {
    ERC20DripsHub internal dripsHub;
    IDai internal dai;

    function setUp() public virtual {
        vm.createSelectFork("mainnet", 15600000);

        dripsHub = ERC20DripsHub(0x73043143e0A6418cc45d82D4505B096b802FD365);
        vm.label(address(dripsHub), "DaiDripsHub");

        dai = IDai(address(dripsHub.erc20()));
        vm.label(address(dai), "Dai");
    }

    function giveDaiTo(address to, uint256 give) internal {
        deal(address(dai), to, give, false);
    }

    // Radicle Drips helpers
    mapping(address => bytes) internal drips;
    mapping(address => bytes) internal currSplitsReceivers;

    function skipToCycleEnd() internal {
        skip(dripsHub.cycleSecs() - (block.timestamp % dripsHub.cycleSecs()));
    }

    function loadDrips(address user)
        internal
        returns (
            uint64 lastUpdate,
            uint128 lastBalance,
            DripsReceiver[] memory currReceivers
        )
    {
        (lastUpdate, lastBalance, currReceivers) = decodeDrips(drips[user]);
        assertDrips(user, lastUpdate, lastBalance, currReceivers);
    }

    function storeDrips(
        address user,
        uint128 newBalance,
        DripsReceiver[] memory newReceivers
    )
        internal
    {
        uint64 currTimestamp = uint64(block.timestamp);
        assertDrips(user, currTimestamp, newBalance, newReceivers);
        drips[user] = abi.encode(currTimestamp, newBalance, newReceivers);
    }

    function decodeDrips(bytes storage encoded)
        internal
        view
        returns (uint64 lastUpdate, uint128 lastBalance, DripsReceiver[] memory)
    {
        if (encoded.length == 0) {
            return (0, 0, new DripsReceiver[](0));
        } else {
            return abi.decode(encoded, (uint64, uint128, DripsReceiver[]));
        }
    }

    function getCurrSplitsReceivers(address user)
        internal
        view
        returns (SplitsReceiver[] memory)
    {
        bytes storage encoded = currSplitsReceivers[user];
        if (encoded.length == 0) {
            return new SplitsReceiver[](0);
        } else {
            return abi.decode(encoded, (SplitsReceiver[]));
        }
    }

    function setCurrSplitsReceivers(
        address user,
        SplitsReceiver[] memory newReceivers
    )
        internal
    {
        currSplitsReceivers[user] = abi.encode(newReceivers);
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
    )
        internal
        pure
        returns (DripsReceiver[] memory list)
    {
        list = new DripsReceiver[](2);
        list[0] = DripsReceiver(user1, amtPerSec1);
        list[1] = DripsReceiver(user2, amtPerSec2);
    }

    function setDrips(
        address user,
        uint128 balanceFrom,
        uint128 balanceTo,
        DripsReceiver[] memory newReceivers
    )
        internal
    {
        int128 balanceDelta = int128(balanceTo) - int128(balanceFrom);
        uint256 expectedBalance =
            uint256(int256(dai.balanceOf(user)) - balanceDelta);
        (
            uint64 lastUpdate,
            uint128 lastBalance,
            DripsReceiver[] memory currReceivers
        ) = loadDrips(user);

        vm.startPrank(user);
        if (balanceDelta > 0) {
            dai.approve(address(dripsHub), uint128(balanceDelta));
        }
        (uint128 newBalance, int128 realBalanceDelta) = dripsHub.setDrips(
            lastUpdate, lastBalance, currReceivers, balanceDelta, newReceivers
        );
        vm.stopPrank();

        storeDrips(user, newBalance, newReceivers);
        assertEq(newBalance, balanceTo, "Invalid drips balance");
        assertEq(realBalanceDelta, balanceDelta, "Invalid real balance delta");
        assertBalance(user, expectedBalance);
    }

    function assertDrips(
        address user,
        uint64 lastUpdate,
        uint128 balance,
        DripsReceiver[] memory currReceivers
    )
        internal
    {
        bytes32 actual = dripsHub.dripsHash(user);
        bytes32 expected =
            dripsHub.hashDrips(lastUpdate, balance, currReceivers);
        assertEq(actual, expected, "Invalid drips configuration");
    }

    function assertDripsBalance(address user, uint128 expected) internal {
        changeBalance(user, expected, expected);
    }

    function changeBalance(address user, uint128 balanceFrom, uint128 balanceTo)
        internal
    {
        (,, DripsReceiver[] memory currReceivers) = loadDrips(user);
        setDrips(user, balanceFrom, balanceTo, currReceivers);
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
    )
        internal
        pure
        returns (SplitsReceiver[] memory list)
    {
        list = new SplitsReceiver[](2);
        list[0] = SplitsReceiver(user1, weight1);
        list[1] = SplitsReceiver(user2, weight2);
    }

    function setSplits(address user, SplitsReceiver[] memory newReceivers)
        internal
    {
        setSplits(user, newReceivers, 0, 0);
    }

    function setSplits(
        address user,
        SplitsReceiver[] memory newReceivers,
        uint128 expectedCollected,
        uint128 expectedSplit
    )
        internal
    {
        SplitsReceiver[] memory curr = getCurrSplitsReceivers(user);
        assertSplits(user, curr);
        assertCollectable(user, expectedCollected, expectedSplit);
        uint256 expectedBalance = dai.balanceOf(user) + expectedCollected;

        vm.startPrank(user);
        (uint128 collected, uint128 split) =
            dripsHub.setSplits(curr, newReceivers);
        vm.stopPrank();

        setCurrSplitsReceivers(user, newReceivers);
        assertSplits(user, newReceivers);
        assertEq(collected, expectedCollected, "Invalid collected amount");
        assertEq(split, expectedSplit, "Invalid split amount");
        assertCollectable(user, 0, 0);
        assertBalance(user, expectedBalance);
    }

    function assertSplits(
        address user,
        SplitsReceiver[] memory expectedReceivers
    )
        internal
    {
        bytes32 actual = dripsHub.splitsHash(user);
        bytes32 expected = dripsHub.hashSplits(expectedReceivers);
        assertEq(actual, expected, "Invalid splits hash");
    }

    function collect(address user, uint128 expectedAmt) internal {
        collect(user, user, expectedAmt, 0);
    }

    function collect(
        address user,
        uint128 expectedCollected,
        uint128 expectedSplit
    )
        internal
    {
        collect(user, user, expectedCollected, expectedSplit);
    }

    function collect(address user, address collected, uint128 expectedAmt)
        internal
    {
        collect(user, collected, expectedAmt, 0);
    }

    function collect(
        address user,
        address collected,
        uint128 expectedCollected,
        uint128 expectedSplit
    )
        internal
    {
        assertCollectable(collected, expectedCollected, expectedSplit);
        uint256 expectedBalance = dai.balanceOf(collected) + expectedCollected;

        (uint128 collectedAmt, uint128 splitAmt) =
            dripsHub.collect(address(collected), getCurrSplitsReceivers(user));

        assertEq(collectedAmt, expectedCollected, "Invalid collected amount");
        assertEq(splitAmt, expectedSplit, "Invalid split amount");
        assertCollectable(collected, 0);
        assertBalance(collected, expectedBalance);
    }

    function assertCollectable(address user, uint128 expected) internal {
        assertCollectable(user, expected, 0);
    }

    function assertCollectable(
        address user,
        uint128 expectedCollected,
        uint128 expectedSplit
    )
        internal
    {
        (uint128 actualCollected, uint128 actualSplit) =
            dripsHub.collectable(user, getCurrSplitsReceivers(user));
        assertEq(actualCollected, expectedCollected, "Invalid collected");
        assertEq(actualSplit, expectedSplit, "Invalid split");
    }

    function flushCycles(
        address user,
        uint64 expectedFlushableBefore,
        uint64 maxCycles,
        uint64 expectedFlushableAfter
    )
        internal
    {
        assertFlushableCycles(user, expectedFlushableBefore);
        assertEq(
            dripsHub.flushCycles(user, maxCycles),
            expectedFlushableAfter,
            "Invalid flushable cycles left"
        );
        assertFlushableCycles(user, expectedFlushableAfter);
    }

    function assertFlushableCycles(address user, uint64 expectedFlushable)
        internal
    {
        assertEq(
            dripsHub.flushableCycles(user),
            expectedFlushable,
            "Invalid flushable cycles"
        );
    }

    function assertBalance(address user, uint256 expected) internal {
        assertEq(dai.balanceOf(user), expected, "Invalid balance");
    }
}
