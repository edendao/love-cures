// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "solmate/tokens/ERC721.sol";
import "solmate/auth/Auth.sol";

contract RandomizedControledTrial is ERC721, Auth {
    ERC721 public ip;
    // RCT ID => Impact Points
    mapping(uint256 => uint16) public impactOf;
    mapping(uint256 => string) internal _tokenURI;

    constructor(address _authority, address _ip)
        ERC721("Open Source Randomized Controled Trial", "openRCT")
        Auth(msg.sender, Authority(_authority))
    {
        ip = ERC721(_ip);
    }

    function tokenURI(uint256 id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return _tokenURI[id];
    }

    event Evaluated(uint256 indexed id, uint16 impactPoints, string dataURI);

    function register(
        uint256 id,
        uint16 impactPoints,
        string memory dataURI
    ) external requiresAuth {
        require(ip.ownerOf(id) != address(0), "INVARIANT");

        _mint(address(this), id);
        _tokenURI[id] = dataURI;
        impactOf[id] = impactPoints;

        emit Evaluated(id, impactPoints, dataURI);
    }
}
