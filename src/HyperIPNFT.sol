// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "./mixins/ERC20StreamsNode.sol";

// Only guaranteed to work with non-transferrable share tokens, e.g. Syndicate DAO
contract HyperIPNFT is ERC20StreamsNode {
    IERC20 public immutable sharesERC20;

    constructor(
        address _dripsHub,
        address _authority,
        address _syndicateERC20
    ) ERC20StreamsNode(_dripsHub, _authority) {
        sharesERC20 = IERC20(_syndicateERC20);
    }

    event Registered(address shareholder, uint256 shares);

    struct Node {
        address account;
        uint256 shares;
        address next;
    }

    address internal firstNodeAccount;
    mapping(address => Node) internal registrations;
    uint256 public registeredCount;

    function register() external {
        address shareholder = msg.sender;
        uint256 shares = sharesERC20.balanceOf(shareholder);

        require(0 < shares, "INVARIANT");
        require(registrations[shareholder].shares != shares, "NO_UPDATE");

        registrations[shareholder].account = shareholder;
        registrations[shareholder].shares = shares;
        emit Registered(shareholder, shares);

        if (firstNodeAccount == address(0)) {
            firstNodeAccount = shareholder;
            unchecked {
                ++registeredCount;
            }
        } else if (shareholder < firstNodeAccount) {
            registrations[shareholder].next = firstNodeAccount;
            firstNodeAccount = shareholder;
            unchecked {
                ++registeredCount;
            }
        } else {
            Node storage previousNode = registrations[firstNodeAccount];
            Node storage node = previousNode;
            while (node.next != address(0) && node.account < shareholder) {
                previousNode = node;
                node = registrations[node.next];
            }
            if (node.account != shareholder) {
                if (shareholder < node.account) {
                    previousNode.next = shareholder;
                    registrations[shareholder].next = node.account;
                } else {
                    node.next = shareholder;
                }
                unchecked {
                    ++registeredCount;
                }
            }
        }

        SplitsReceiver[] memory newReceivers = new SplitsReceiver[](
            registeredCount
        );
        uint256 i = 0;
        uint256 totalSupply = sharesERC20.totalSupply();
        uint32 maxTotalWeight = dripsHub.TOTAL_SPLITS_WEIGHT();

        for (
            Node memory node = registrations[firstNodeAccount];
            node.account != address(0);
            node = registrations[node.next]
        ) {
            newReceivers[i++] = SplitsReceiver(
                node.account,
                uint32((maxTotalWeight * node.shares) / totalSupply)
            );
        }

        _setSplits(newReceivers);
    }
}
