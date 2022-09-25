// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {Hypercert} from "src/Hypercert.sol";
import {Evaluation} from "src/Evaluation.sol";

abstract contract HypercertSystem is Test {
    // Mock contracts pending final Hypercert & Evaluation standard from Filecoin
    Hypercert internal hypercert;
    Evaluation internal evaluation;

    function setUp() public virtual {
        hypercert = new Hypercert();
        evaluation = new Evaluation(address(hypercert));
    }
}
