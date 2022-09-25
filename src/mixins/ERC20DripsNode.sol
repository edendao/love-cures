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

    function collect()
        public
        returns (uint128 collectedAmount, uint128 splitAmount)
    {
        return dripsHub.collect(address(this), currentSplitsReceivers());
    }

    /// @notice Gives funds from the node to the receiver.
    /// The receiver can collect them immediately.
    /// Transfers the funds to be given from the node's wallet to the drips hub contract.
    /// @param receiver The receiver
    /// @param amount The given amount
    function _give(address receiver, uint128 amount) internal {
        dripsHub.erc20().approve(address(dripsHub), amount);
        dripsHub.give(receiver, amount);
    }

    /// @notice Sets the node's drips configuration.
    /// Transfers funds between the node and the drips hub contract
    /// to fulfill the change of the drips balance.
    /// @param totalDrip The total amount to be dripped.
    /// @param newReceivers The list of the drips receivers of the node or the account to be set.
    /// Must be sorted by the receivers' addresses, deduplicated and without 0 amtPerSecs.
    /// @return newBalance The new drips balance of the node.
    /// @return realBalanceDelta The actually applied drips balance change.
    function _setDrips(uint128 totalDrip, DripsReceiver[] memory newReceivers)
        internal
        returns (uint128 newBalance, int128 realBalanceDelta)
    {
        (
            uint64 lastUpdate,
            uint128 lastBalance,
            DripsReceiver[] memory currReceivers
        ) = loadDrips();

        int128 balanceDelta = int128(totalDrip) - int128(lastBalance);
        if (balanceDelta > 0) {
            dripsHub.erc20().approve(address(dripsHub), uint128(balanceDelta));
        }

        (newBalance, realBalanceDelta) = dripsHub.setDrips(
            lastUpdate, lastBalance, currReceivers, balanceDelta, newReceivers
        );

        encodedDrips =
            abi.encode(uint64(block.timestamp), newBalance, newReceivers);
    }

    /// @notice Collects funds received by the node and sets their splits.
    /// The collected funds are split according to `currReceivers`.
    /// @param newReceivers The new list of the user's splits receivers.
    /// Must be sorted by the splits receivers' addresses, deduplicated and without 0 weights.
    /// Each splits receiver will be getting `weight / 1_000_000`
    /// share of the funds collected by the node.
    /// @return collected The collected amount
    /// @return split The amount split to the node's splits receivers
    function _setSplits(SplitsReceiver[] memory newReceivers)
        internal
        returns (uint128 collected, uint128 split)
    {
        (collected, split) =
            dripsHub.setSplits(currentSplitsReceivers(), newReceivers);

        encodedCurrentSplitsReceivers = abi.encode(newReceivers);
    }
}
