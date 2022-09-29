// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "./mixins/ERC20StreamsNode.sol";

contract ImpactSplitter is ERC20StreamsNode {
    constructor(address _dripsHub, address _authority)
        ERC20StreamsNode(_dripsHub, _authority)
    {}

    function setImpactSplits(SplitsReceiver[] memory newReceivers)
        external
        requiresAuth
        returns (uint128 collectedAmount, uint128 streamedAmount)
    {
        (collectedAmount, streamedAmount) = _normalizeAndSetSplits(
            newReceivers
        );
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
    }
}
