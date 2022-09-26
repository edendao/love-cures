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
    mapping(address => Node) internal nodes;
    uint256 public registrations;

    function register(address[] memory accounts) external requiresAuth {
        uint256 count = accounts.length;
        require(count > 0, "EMPTY_LIST");
        for (uint256 i = 0; i < count; ) {
            _register(accounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function register() external {
        _register(msg.sender);
    }

    function _register(address shareholder) internal {
        uint256 shares = sharesERC20.balanceOf(shareholder);

        require(shares > 0, "INVALID_SHAREHOLDER");
        require(nodes[shareholder].shares != shares, "NO_UPDATE");

        nodes[shareholder].account = shareholder;
        nodes[shareholder].shares = shares;
        emit Registered(shareholder, shares);

        if (firstNodeAccount == address(0)) {
            firstNodeAccount = shareholder;
            unchecked {
                ++registrations;
            }
        } else if (shareholder < firstNodeAccount) {
            nodes[shareholder].next = firstNodeAccount;
            firstNodeAccount = shareholder;
            unchecked {
                ++registrations;
            }
        } else {
            Node storage previousNode = nodes[firstNodeAccount];
            Node storage node = previousNode;
            while (node.next != address(0) && node.account < shareholder) {
                previousNode = node;
                node = nodes[node.next];
            }
            if (node.account != shareholder) {
                if (shareholder < node.account) {
                    previousNode.next = shareholder;
                    nodes[shareholder].next = node.account;
                } else {
                    node.next = shareholder;
                }
                unchecked {
                    ++registrations;
                }
            }
        }

        SplitsReceiver[] memory newReceivers = new SplitsReceiver[](
            registrations
        );
        uint256 i = 0;
        uint256 totalSupply = sharesERC20.totalSupply();
        uint32 maxTotalWeight = dripsHub.TOTAL_SPLITS_WEIGHT();

        for (
            Node memory node = nodes[firstNodeAccount];
            node.account != address(0);
            node = nodes[node.next]
        ) {
            newReceivers[i] = SplitsReceiver(
                node.account,
                uint32((maxTotalWeight * node.shares) / totalSupply)
            );
            unchecked {
                ++i;
            }
        }

        _setSplits(newReceivers);
    }
}
