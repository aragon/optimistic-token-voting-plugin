// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {OptimisticTokenVotingPluginSetup} from "../src/OptimisticTokenVotingPluginSetup.sol";

contract OptimisticTokenVotingPluginSetupTest is Test {
    OptimisticTokenVotingPluginSetup public plugin;
    error Unimplemented();

    function setUp() public {
        // plugin = new OptimisticTokenVotingPluginSetup();
        // plugin.setNumber(0);
    }

    function test_Increment() public {
        // plugin.increment();
        // assertEq(plugin.number(), 1);
        revert Unimplemented();
    }

    function testFuzz_SetNumber(uint256 x) public {
        // plugin.setNumber(x);
        // assertEq(plugin.number(), x);
        revert Unimplemented();
    }
}
