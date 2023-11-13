// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {OptimisticTokenVotingPluginSetup} from "../src/OptimisticTokenVotingPluginSetup.sol";

contract OptimisticTokenVotingPluginSetupTest is Test {
    OptimisticTokenVotingPluginSetup public plugin;

    function setUp() public {
        // plugin = new OptimisticTokenVotingPluginSetup();
        // plugin.setNumber(0);
    }

    function test_Increment() public {
        // plugin.increment();
        // assertEq(plugin.number(), 1);
    }

    function testFuzz_SetNumber(uint256 x) public {
        // plugin.setNumber(x);
        // assertEq(plugin.number(), x);
    }
}
