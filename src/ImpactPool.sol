// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "openzeppelin-contracts/interfaces/IERC1155.sol";

import "solmate/auth/Auth.sol";

import "./mixins/ERC20StreamsNode.sol";

contract ImpactPool is ERC20StreamsNode, Auth {
    constructor(address _dripsHub, address _authority)
        ERC20StreamsNode(ERC20DripsHub(_dripsHub))
        Auth(msg.sender, Authority(_authority))
    {}

    /*
     * Authorized callers can update the split,

     * @notice this normalizes the new split `weights` as if they were "Impact Points"
     * @notice the total sum of impact points cannot be equal to or greater than 1_000_000
     */
    function updateSplits(SplitsReceiver[] memory newSplits)
        external
        requiresAuth
        returns (uint128 collectedAmount, uint128 streamedAmount)
    {
        uint32 totalWeight = dripsHub.TOTAL_SPLITS_WEIGHT();
        uint256 totalInputWeight = 0;

        for (uint256 i = 0; i < newSplits.length; ) {
            totalInputWeight += newSplits[i].weight;

            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < newSplits.length; ) {
            newSplits[i].weight = uint32(
                (newSplits[i].weight * totalWeight) / totalInputWeight
            );

            unchecked {
                ++i;
            }
        }

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
    }
}
