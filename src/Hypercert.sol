// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "solmate/test/utils/mocks/MockERC1155.sol";

contract Hypercert is MockERC1155 {
    uint256 public totalSupply;
    mapping(uint256 => address) public creator;

    function mint(bytes memory data) public virtual returns (uint256 id) {
        id = totalSupply++;
        creator[id] = msg.sender;
        super.mint(msg.sender, id, 1, data);
    }

    function mint(address, uint256, uint256, bytes memory)
        public
        pure
        override
    {
        revert("NOT_IMPLEMENTED");
    }
}
