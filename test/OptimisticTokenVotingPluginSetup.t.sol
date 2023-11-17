// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {OptimisticTokenVotingPluginSetup} from "../src/OptimisticTokenVotingPluginSetup.sol";
import {GovernanceERC20} from "@aragon/osx/token/ERC20/governance/GovernanceERC20.sol";
import {GovernanceWrappedERC20} from "@aragon/osx/token/ERC20/governance/GovernanceWrappedERC20.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract OptimisticTokenVotingPluginSetupTest is Test {
    OptimisticTokenVotingPluginSetup public pluginSetup;
    GovernanceERC20 governanceERC20Base;
    GovernanceWrappedERC20 governanceWrappedERC20Base;

    error Unimplemented();

    function setUp() public {
        if (address(governanceERC20Base) == address(0x0)) {
            // Base
            GovernanceERC20.MintSettings memory mintSettings = GovernanceERC20
                .MintSettings(new address[](0), new uint256[](0));
            governanceERC20Base = new GovernanceERC20(
                IDAO(address(0x0)),
                "",
                "",
                mintSettings
            );
            // Base
            governanceWrappedERC20Base = new GovernanceWrappedERC20(
                IERC20Upgradeable(address(0x0)),
                "",
                ""
            );
        }

        pluginSetup = new OptimisticTokenVotingPluginSetup(
            governanceERC20Base,
            governanceWrappedERC20Base
        );
    }
}
