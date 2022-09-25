// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "openzeppelin-contracts/interfaces/IERC1155.sol";

import "solmate/auth/Auth.sol";

import "./mixins/ERC20DripsNode.sol";

contract ImpactStreamer is ERC20DripsNode, Auth {
    constructor(address _dripsHub, address _authority)
        ERC20DripsNode(ERC20DripsHub(_dripsHub))
        Auth(msg.sender, Authority(_authority))
    {}

    /*
     * Authorized callers can update the split,

     * @notice this normalizes the new split `weights` as if they were "Impact Points"
     * @notice the total sum of impact points cannot be equal to or greater than 1_000_000
     */
    function updateStreams(SplitsReceiver[] memory newSplits)
        external
        requiresAuth
    {
        uint256 totalImpactPoints = 0;

        for (uint256 i = 0; i < newSplits.length;) {
            totalImpactPoints += newSplits[i].weight;

            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < newSplits.length;) {
            newSplits[i].weight =
                uint32(newSplits[i].weight / totalImpactPoints);

            unchecked {
                ++i;
            }
        }

        _setSplits(newSplits);
    }
}
