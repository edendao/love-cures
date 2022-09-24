// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "./Hypercert.sol";

contract Evaluation is Hypercert {
    address public hypercertAddress;
    mapping(uint256 => uint256) public hypercert;

    constructor(address _hypercertAddress) {
        hypercertAddress = _hypercertAddress;
    }

    function mint(bytes memory) public pure override returns (uint256) {
        revert("NOT_IMPLEMENTED");
    }

    function mint(uint256 hypercertId, bytes memory data)
        public
        returns (uint256 id)
    {
        id = super.mint(data);
        hypercert[id] = hypercertId;
    }
}
