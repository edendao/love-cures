// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "openzeppelin-contracts/interfaces/IERC1155.sol";
import "solmate/auth/Auth.sol";

import "./mixins/ERC20DripsNode.sol";

/*
 * The PrizePool contract streams a configurable % of its inflows to
 * the target recipient, in our case the OutcomePaymentsStreamer
 */
contract PrizePool is ERC20DripsNode, Auth {
    constructor(address _dripsHub, address _authority)
        ERC20DripsNode(ERC20DripsHub(_dripsHub))
        Auth(msg.sender, Authority(_authority))
    {}

    uint256 public lockedUntil;

    /*
     * Authorized callers can update the receiver & flow rate, and immediately
     * gives (flowBasisPoints / 10_000)% of its balance to the receiver */
    function giveTo(address receiverAddress, uint128 giveAmount, uint16 flowBasisPoints, uint64 lockTimeInSeconds)
        external
        requiresAuth
        returns (uint128 newBalance, int128 realBalanceDelta, uint128 collectedAmount, uint128 splitAmount)
    {
        require(lockedUntil < block.timestamp, "STREAM_LOCKED");
        require(receiverAddress != address(0) && flowBasisPoints != 0, "INVALID_CONFIG");
        lockedUntil = block.timestamp + lockTimeInSeconds;

        // Give directly
        if (giveAmount > 0) {
            _give(receiverAddress, giveAmount);
        }

        // Drip until `lockedUntil`
        uint128 dripPerSecond = uint128(balance() * flowBasisPoints / 10000) / lockTimeInSeconds;
        DripsReceiver[] memory newDrips = new DripsReceiver[](1);
        newDrips[0] = DripsReceiver(receiverAddress, dripPerSecond);
        (newBalance, realBalanceDelta) = _setDrips(dripPerSecond * lockTimeInSeconds, newDrips);

        // Automatically forward incoming drips to the receiver
        SplitsReceiver[] memory newSplits = new SplitsReceiver[](1);
        newSplits[0] = SplitsReceiver(receiverAddress, dripsHub.TOTAL_SPLITS_WEIGHT() * flowBasisPoints / 10000);
        (collectedAmount, splitAmount) = _setSplits(newSplits);
    }

    function emergencyShutdown()
        external
        requiresAuth
        returns (uint128 newBalance, int128 realBalanceDelta, uint128 collectedAmount, uint128 splitAmount)
    {
        SplitsReceiver[] memory newSplits = new SplitsReceiver[](0);
        DripsReceiver[] memory newDrips = new DripsReceiver[](0);

        (newBalance, realBalanceDelta) = _setDrips(0, newDrips);
        (collectedAmount, splitAmount) = _setSplits(newSplits);

        lockedUntil = block.timestamp;
    }
}
