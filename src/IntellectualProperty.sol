// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "solmate/tokens/ERC721.sol";
import "solmate/auth/Auth.sol";

contract IntellectualProperty is ERC721, Auth {
    uint256 public totalSupply;

    constructor(address _authority)
        ERC721("Open Source Intellectual Property", "openIP")
        Auth(msg.sender, Authority(_authority))
    {}

    mapping(uint256 => string) internal _tokenURI;

    function tokenURI(uint256 id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return _tokenURI[id];
    }

    enum RCT {
        PROPOSED, // Proposed treatment protocol
        APPROVED, // RCTs approved, clear for RCTs to begin
        COMPLETED // RCTs complete, Hypercert represents PROVED or DISPROVED impact
    }

    enum Hypothesis {
        PROPOSED,
        DISPROVED,
        PROVED
    }

    struct State {
        Hypothesis hypothesis;
        RCT rct;
    }

    mapping(uint256 => State) public stateOf;

    event Update(
        uint256 indexed id,
        Hypothesis indexed hypothesis,
        RCT indexed rct,
        string uri
    );

    // Anyone can mint IP optimistically
    function mint(string memory uri) public returns (uint256 id) {
        id = totalSupply++;
        _mint(msg.sender, id);
        _tokenURI[id] = uri;
        emit Update(id, Hypothesis.PROPOSED, RCT.PROPOSED, uri);
    }

    // Owners can update the URI
    function update(uint256 id, string memory uri) external {
        require(msg.sender == _ownerOf[id], "UNAUTHORIZED");
        _tokenURI[id] = uri;
        State memory s = stateOf[id];
        emit Update(id, s.hypothesis, s.rct, uri);
    }

    // Medical Committee can approve
    function approveTreatmentProtocol(uint256 id) external requiresAuth {
        State storage s = stateOf[id];
        s.rct = RCT.APPROVED;
        emit Update(id, s.hypothesis, RCT.APPROVED, _tokenURI[id]);
    }

    // Medical Committee can update the hypothesis
    function updateHypothesis(uint256 id, Hypothesis hypothesis)
        external
        requiresAuth
    {
        State storage s = stateOf[id];
        // Permissive to allow the Medical Committee to update Hypothesis
        // from PROVED => DISPROVED or DISPROVED => PROVED given sufficient evidence
        require(
            s.rct != RCT.PROPOSED && hypothesis != Hypothesis.PROPOSED,
            "INVARIANT"
        );
        s.hypothesis = hypothesis;
        s.rct = RCT.COMPLETED;
        emit Update(id, hypothesis, RCT.COMPLETED, _tokenURI[id]);
    }
}
