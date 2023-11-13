// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {OptimisticTokenVotingPlugin} from "../src/OptimisticTokenVotingPlugin.sol";

contract OptimisticTokenVotingPluginTest is Test {
    OptimisticTokenVotingPlugin public plugin;
    error Unimplemented();

    function setUp() public {
        plugin = new OptimisticTokenVotingPlugin();
        
        revert Unimplemented();
    }

    function test_OnlyProposers() public {}
    function test_NonProposersCannotCreate() public {}
    function test_CorrectDates() public {}

    function testFuzz_SetNumber(uint256 x) public {
        revert Unimplemented();
    }
}
