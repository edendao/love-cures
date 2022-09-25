// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "openzeppelin-contracts/interfaces/IERC1155.sol";
import "solmate/auth/Auth.sol";

import "./mixins/ERC20StreamsNode.sol";

/*
 * The PrizePool contract streams a configurable % of its inflows to
 * the target recipient, in our case the OutcomePaymentsStreamer
 *
 * After setting the Stream, additional inflows will flow through to the receiver.
 * Only after the lock has expired, an authorized party can create a new Stream.
 */
contract PrizePool is ERC20StreamsNode, Auth {
    uint256 public lockedUntil;

    constructor(address _dripsHub, address _authority)
        ERC20StreamsNode(ERC20DripsHub(_dripsHub))
        Auth(msg.sender, Authority(_authority))
    {}

    /*
     * Authorized callers can update the receiver & flow rate, and immediately
     * gives (flowBasisPoints / 10_000)% of its balance to the receiver
     */
    function streamTo(
        address receiverAddress,
        uint16 flowBasisPoints,
        uint64 lockTimeInSeconds
    )
        external
        requiresAuth
        returns (
            uint128 newBalance,
            int128 realBalanceDelta,
            uint128 collectedAmount,
            uint128 streamedAmount
        )
    {
        require(lockedUntil < block.timestamp, "STREAM_LOCKED");
        require(
            receiverAddress != address(0) && flowBasisPoints != 0,
            "INVALID_CONFIG"
        );
        lockedUntil = block.timestamp + lockTimeInSeconds;

        // Drip until `lockedUntil`
        uint128 dripPerSecond = uint128(
            (balance() * flowBasisPoints) / (lockTimeInSeconds * 10000)
        );
        DripsReceiver[] memory newDrips = new DripsReceiver[](1);
        newDrips[0] = DripsReceiver(receiverAddress, dripPerSecond);
        (newBalance, realBalanceDelta) = _setDrips(
            dripPerSecond * lockTimeInSeconds,
            newDrips
        );

        // Automatically forward incoming drips to the receiver
        SplitsReceiver[] memory newSplits = new SplitsReceiver[](1);
        newSplits[0] = SplitsReceiver(
            receiverAddress,
            (dripsHub.TOTAL_SPLITS_WEIGHT() / 10000) * flowBasisPoints
        );
        (collectedAmount, streamedAmount) = _setSplits(newSplits);
    }

    function emergencyShutdown()
        external
        requiresAuth
        returns (
            uint128 newBalance,
            int128 realBalanceDelta,
            uint128 collectedAmount,
            uint128 streamedAmount
        )
    {
        (
            newBalance,
            realBalanceDelta,
            collectedAmount,
            streamedAmount
        ) = _emergencyShutdown();
        lockedUntil = block.timestamp;
    }
}
