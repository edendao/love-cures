// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "drips-contracts/ERC20DripsHub.sol";

contract ERC20DripsNode {
    ERC20DripsHub internal immutable dripsHub;

    constructor(ERC20DripsHub _dripsHub) {
        dripsHub = _dripsHub;
    }

    function balance() public view returns (uint256) {
        return dripsHub.erc20().balanceOf(address(this));
    }

    bytes internal encodedDrips;
    bytes internal encodedCurrentSplitsReceivers;

    function loadDrips()
        public
        view
        returns (
            uint64 lastUpdate,
            uint128 lastBalance,
            DripsReceiver[] memory currentReceivers
        )
    {
        bytes memory encoded = encodedDrips;
        if (encoded.length == 0) {
            return (0, 0, new DripsReceiver[](0));
        } else {
            return abi.decode(encoded, (uint64, uint128, DripsReceiver[]));
        }
    }

    function currentSplitsReceivers()
        public
        view
        returns (SplitsReceiver[] memory)
    {
        bytes memory encoded = encodedCurrentSplitsReceivers;
        if (encoded.length == 0) {
            return new SplitsReceiver[](0);
        } else {
            return abi.decode(encoded, (SplitsReceiver[]));
        }
    }

    /// @notice Sets the user's or the account's drips configuration.
    /// Transfers funds between the node and the drips hub contract
    /// to fulfill the change of the drips balance.
    /// @param balanceDelta The drips balance change to be applied.
    /// Positive to add funds to the drips balance, negative to remove them.
    /// @param newReceivers The list of the drips receivers of the user or the account to be set.
    /// Must be sorted by the receivers' addresses, deduplicated and without 0 amtPerSecs.
    /// @return newBalance The new drips balance of the user or the account.
    /// Pass it as `lastBalance` when updating that user or the account for the next time.
    /// @return realBalanceDelta The actually applied drips balance change.
    function _setDrips(int128 balanceDelta, DripsReceiver[] memory newReceivers)
        internal
        returns (uint128 newBalance, int128 realBalanceDelta)
    {
        if (balanceDelta > 0) {
            dripsHub.erc20().approve(address(dripsHub), uint128(balanceDelta));
        }
        (
            uint64 lastUpdate,
            uint128 lastBalance,
            DripsReceiver[] memory currReceivers
        ) = loadDrips();

        return dripsHub.setDrips(
            lastUpdate, lastBalance, currReceivers, balanceDelta, newReceivers
        );
    }

    /// @notice Gives funds from the user or their account to the receiver.
    /// The receiver can collect them immediately.
    /// Transfers the funds to be given from the user's wallet to the drips hub contract.
    /// @param receiver The receiver
    /// @param amt The given amount
    function _give(address receiver, uint128 amt) internal {
        dripsHub.erc20().approve(address(dripsHub), amt);
        dripsHub.give(receiver, amt);
    }

    /// @notice Collects funds received by the node and sets their splits.
    /// The collected funds are split according to `currReceivers`.
    /// @param newReceivers The new list of the user's splits receivers.
    /// Must be sorted by the splits receivers' addresses, deduplicated and without 0 weights.
    /// Each splits receiver will be getting `weight / 1_000_000`
    /// share of the funds collected by the user.
    /// @return collected The collected amount
    /// @return split The amount split to the user's splits receivers
    function _setSplits(SplitsReceiver[] memory newReceivers)
        internal
        returns (uint128 collected, uint128 split)
    {
        return dripsHub.setSplits(currentSplitsReceivers(), newReceivers);
    }
}
