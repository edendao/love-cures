// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "openzeppelin-contracts/interfaces/IERC1155.sol";

import "solmate/auth/Auth.sol";

import "./mixins/ERC20DripsNode.sol";

/*
 * The PrizeStreamer contract streams a configurable % of its inflows to
 * the target recipient, in our case the OutcomePaymentsStreamer
 */
contract PrizeStreamer is ERC20DripsNode, Auth {
    constructor(address _dripsHub, address _authority)
        ERC20DripsNode(ERC20DripsHub(_dripsHub))
        Auth(msg.sender, Authority(_authority))
    {}

    uint256 public lockedUntil;

    /*
     * Authorized callers can update the receiver & flow rate, and immediately
     * gives (basisPoints / 10_000)% of its balance to the receiver
     */
    function streamTo(
        address receiverAddress,
        uint32 basisPoints,
        uint64 lockTimeInSeconds
    )
        external
        requiresAuth
    {
        require(lockedUntil < block.timestamp, "STREAM_LOCKED");
        lockedUntil = block.timestamp + lockTimeInSeconds;

        SplitsReceiver[] memory newSplits;
        DripsReceiver[] memory newDrips;
        int128 newDripAmount;

        if (receiverAddress == address(0) || basisPoints == 0) {
            newSplits = new SplitsReceiver[](0);
            newDrips = new DripsReceiver[](0);
            newDripAmount = 0;
        } else {
            newSplits = new SplitsReceiver[](1);
            newSplits[0] = SplitsReceiver(
                receiverAddress,
                dripsHub.TOTAL_SPLITS_WEIGHT() * basisPoints / 10000
            );
            newDrips = new DripsReceiver[](1);
            newDripAmount = int128(uint128(balance() * basisPoints / 10000));
            newDrips[0] = DripsReceiver(
                receiverAddress, uint128(newDripAmount) / lockTimeInSeconds
            );
        }

        _setSplits(newSplits);
        _setDrips(newDripAmount, newDrips);
    }
}
