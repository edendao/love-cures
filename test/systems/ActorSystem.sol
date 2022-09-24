// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {Dai} from "drips-contracts/test/TestDai.sol";

contract ActorSystem is Test {
    Dai internal DAI = new Dai();

    // These can be an End Owner Account (e.g. MetaMask / Social Sign In), Multisig, or Contract
    address internal ops = makeAddr("ops");
    address internal philanthropist = makeAddr("philanthropist");
    address internal council = makeAddr("council");
    address internal evaluator = makeAddr("evaluator");
    address internal researcher = makeAddr("researcher");
    address internal investor = makeAddr("investor");

    function setUp() public virtual {
        vm.deal(ops, 100 ether);
        vm.deal(philanthropist, 100 ether);
        vm.deal(council, 100 ether);
        vm.deal(evaluator, 100 ether);
        vm.deal(researcher, 100 ether);
        vm.deal(investor, 100 ether);

        DAI.transfer(philanthropist, 1000000 ether);
        DAI.transfer(investor, 100000 ether);
    }
}
