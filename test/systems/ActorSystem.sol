// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

abstract contract ActorSystem is Test {
    // These can be an End Owner Account (e.g. MetaMask / Social Sign In), Multisig, or Contract
    address internal committee;
    address internal evaluator;
    address internal investor;
    address internal ops;
    address internal philanthropist;
    address internal researcher;

    address internal receiver1;
    address internal receiver2;
    address internal receiver3;

    function setUp() public virtual {
        committee = createActor("committee", 100 ether);
        evaluator = createActor("evaluator", 100 ether);
        investor = createActor("investor", 100 ether);
        ops = createActor("ops", 100 ether);
        philanthropist = createActor("philanthropist", 100 ether);
        researcher = createActor("researcher", 100 ether);

        // Receivers of impact flow, sorted by address
        receiver1 = makeAddr("receiver1");
        receiver2 = makeAddr("receiver2");
        receiver3 = makeAddr("receiver3");
        if (receiver1 > receiver2) {
            (receiver1, receiver2) = (receiver2, receiver1);
        }
        if (receiver2 > receiver3) {
            (receiver2, receiver3) = (receiver3, receiver2);
        }
        if (receiver1 > receiver2) {
            (receiver1, receiver2) = (receiver2, receiver1);
        }
    }

    function createActor(string memory name, uint256 ethInWei)
        internal
        virtual
        returns (address actor)
    {
        actor = makeAddr(name);
        deal(actor, ethInWei);
    }
}
