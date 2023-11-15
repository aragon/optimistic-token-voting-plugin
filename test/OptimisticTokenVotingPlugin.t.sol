// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {OptimisticTokenVotingPlugin} from "../src/OptimisticTokenVotingPlugin.sol";
import {IOptimisticTokenVoting} from "../src/IOptimisticTokenVoting.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {IProposal} from "@aragon/osx/core/plugin/proposal/IProposal.sol";
import {IMembership} from "@aragon/osx/core/plugin/membership/IMembership.sol";
import {RATIO_BASE} from "@aragon/osx/plugins/utils/Ratio.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

contract OptimisticTokenVotingPluginTest is Test {
    address immutable daoBase = address(new DAO());
    address immutable pluginBase = address(new OptimisticTokenVotingPlugin());
    address immutable votingTokenBase = address(new ERC20Mock());

    DAO public dao;
    OptimisticTokenVotingPlugin public plugin;
    ERC20Mock votingToken;

    address alice = address(0xa11ce);
    address bob = address(0xB0B);
    address randomWallet = vm.addr(1234567890);

    // Events from external contracts
    event Initialized(uint8 version);
    error Unimplemented();

    function setUp() public {
        vm.startPrank(alice);

        // Deploy a DAO with Alice as root
        dao = DAO(
            payable(
                createProxyAndCall(
                    address(daoBase),
                    abi.encodeWithSelector(
                        DAO.initialize.selector,
                        "",
                        alice,
                        address(0x0),
                        ""
                    )
                )
            )
        );

        // Deploy ERC20 token
        votingToken = ERC20Mock(
            createProxyAndCall(
                address(votingTokenBase),
                abi.encodeWithSelector(ERC20Mock.initialize.selector)
            )
        );

        // Deploy a new plugin instance
        OptimisticTokenVotingPlugin.OptimisticGovernanceSettings
            memory settings = OptimisticTokenVotingPlugin
                .OptimisticGovernanceSettings({
                    minVetoRatio: uint32(RATIO_BASE / 10),
                    minDuration: 10 days,
                    minProposerVotingPower: 0
                });

        plugin = OptimisticTokenVotingPlugin(
            createProxyAndCall(
                address(pluginBase),
                abi.encodeWithSelector(
                    OptimisticTokenVotingPlugin.initialize.selector,
                    dao,
                    settings,
                    votingToken
                )
            )
        );

        // The plugin can execute on the DAO
        dao.grant(address(dao), address(plugin), dao.EXECUTE_PERMISSION_ID());

        // Alice can create proposals on the plugin
        dao.grant(address(plugin), alice, plugin.PROPOSER_PERMISSION_ID());
    }

    function test_InitializeRevertsIfInitialized() public {
        OptimisticTokenVotingPlugin.OptimisticGovernanceSettings
            memory settings = OptimisticTokenVotingPlugin
                .OptimisticGovernanceSettings({
                    minVetoRatio: uint32(RATIO_BASE / 10),
                    minDuration: 10 days,
                    minProposerVotingPower: 0
                });

        vm.expectRevert(
            bytes("Initializable: contract is already initialized")
        );
        plugin.initialize(dao, settings, votingToken);
    }

    function test_InitializeSetsTheProperValues() public {
        // Initial settings
        OptimisticTokenVotingPlugin.OptimisticGovernanceSettings
            memory settings = OptimisticTokenVotingPlugin
                .OptimisticGovernanceSettings({
                    minVetoRatio: uint32(RATIO_BASE / 10),
                    minDuration: 10 days,
                    minProposerVotingPower: 0
                });
        plugin = OptimisticTokenVotingPlugin(
            createProxyAndCall(
                address(pluginBase),
                abi.encodeWithSelector(
                    OptimisticTokenVotingPlugin.initialize.selector,
                    dao,
                    settings,
                    votingToken
                )
            )
        );
        assertEq(
            plugin.totalVotingPower(block.number - 1),
            0,
            "Incorrect token supply"
        );
        assertEq(
            plugin.minVetoRatio(),
            uint32(RATIO_BASE / 10),
            "Incorrect minVetoRatio"
        );
        assertEq(plugin.minDuration(), 10 days, "Incorrect minDuration");
        assertEq(
            plugin.minProposerVotingPower(),
            0,
            "Incorrect minProposerVotingPower"
        );

        // Different minVetoRatio
        settings.minVetoRatio = uint32(RATIO_BASE / 5);
        plugin = OptimisticTokenVotingPlugin(
            createProxyAndCall(
                address(pluginBase),
                abi.encodeWithSelector(
                    OptimisticTokenVotingPlugin.initialize.selector,
                    dao,
                    settings,
                    votingToken
                )
            )
        );
        assertEq(
            plugin.minVetoRatio(),
            uint32(RATIO_BASE / 5),
            "Incorrect minVetoRatio"
        );

        // Different minDuration
        settings.minDuration = 25 days;
        plugin = OptimisticTokenVotingPlugin(
            createProxyAndCall(
                address(pluginBase),
                abi.encodeWithSelector(
                    OptimisticTokenVotingPlugin.initialize.selector,
                    dao,
                    settings,
                    votingToken
                )
            )
        );
        assertEq(plugin.minDuration(), 25 days, "Incorrect minDuration");

        // A token with 10 eth supply
        votingToken = ERC20Mock(
            createProxyAndCall(
                address(votingTokenBase),
                abi.encodeWithSelector(ERC20Mock.initialize.selector)
            )
        );
        votingToken.mint(alice, 10 ether);
        vm.roll(block.number + 5);

        plugin = OptimisticTokenVotingPlugin(
            createProxyAndCall(
                address(pluginBase),
                abi.encodeWithSelector(
                    OptimisticTokenVotingPlugin.initialize.selector,
                    dao,
                    settings,
                    votingToken
                )
            )
        );
        assertEq(
            plugin.totalVotingPower(block.number - 1),
            10 ether,
            "Incorrect token supply"
        );

        // Different minProposerVotingPower
        settings.minProposerVotingPower = 1 ether;
        plugin = OptimisticTokenVotingPlugin(
            createProxyAndCall(
                address(pluginBase),
                abi.encodeWithSelector(
                    OptimisticTokenVotingPlugin.initialize.selector,
                    dao,
                    settings,
                    votingToken
                )
            )
        );
        assertEq(
            plugin.minProposerVotingPower(),
            1 ether,
            "Incorrect minProposerVotingPower"
        );
    }

    function test_InitializeCreatesANewERC20Token() public {
        revert Unimplemented();
    }

    function test_InitializeWrapsAnExistingToken() public {
        revert Unimplemented();
    }

    function test_InitializeUsesAnExistingERC20Token() public {
        revert Unimplemented();
    }

    function test_InitializeEmitsEvent() public {
        OptimisticTokenVotingPlugin.OptimisticGovernanceSettings
            memory settings = OptimisticTokenVotingPlugin
                .OptimisticGovernanceSettings({
                    minVetoRatio: uint32(RATIO_BASE / 10),
                    minDuration: 10 days,
                    minProposerVotingPower: 0
                });

        vm.expectEmit();
        emit Initialized(uint8(1));

        plugin = OptimisticTokenVotingPlugin(
            createProxyAndCall(
                address(pluginBase),
                abi.encodeWithSelector(
                    OptimisticTokenVotingPlugin.initialize.selector,
                    dao,
                    settings,
                    votingToken
                )
            )
        );
    }

    function test_SupportsOptimisticGovernanceInterface() public {
        bool supported = plugin.supportsInterface(
            plugin.OPTIMISTIC_GOVERNANCE_INTERFACE_ID()
        );
        assertEq(
            supported,
            true,
            "Should support OPTIMISTIC_GOVERNANCE_INTERFACE_ID"
        );
    }

    function test_SupportsIOptimisticTokenVotingInterface() public {
        bool supported = plugin.supportsInterface(
            type(IOptimisticTokenVoting).interfaceId
        );
        assertEq(supported, true, "Should support IOptimisticTokenVoting");
    }

    function test_SupportsIMembershipInterface() public {
        bool supported = plugin.supportsInterface(
            type(IMembership).interfaceId
        );
        assertEq(supported, true, "Should support IMembership");
    }

    function test_SupportsIProposalInterface() public {
        bool supported = plugin.supportsInterface(type(IProposal).interfaceId);
        assertEq(supported, true, "Should support IProposal");
    }

    function test_SupportsIERC165UpgradeableInterface() public {
        bool supported = plugin.supportsInterface(
            type(IERC165Upgradeable).interfaceId
        );
        assertEq(supported, true, "Should support IERC165Upgradeable");
    }

    function testFuzz_SupportsInterfaceReturnsFalseOtherwise(
        bytes4 _randomInterfaceId
    ) public {
        bool supported = plugin.supportsInterface(bytes4(0x000000));
        assertEq(supported, false, "Should not support any other interface");

        supported = plugin.supportsInterface(bytes4(0xffffffff));
        assertEq(supported, false, "Should not support any other interface");

        supported = plugin.supportsInterface(_randomInterfaceId);
        assertEq(supported, false, "Should not support any other interface");
    }

    function test_GetVotingTokenReturnsTheRightAddress() public {
        assertEq(
            address(plugin.getVotingToken()),
            address(votingToken),
            "Incorrect voting token"
        );

        address oldToken = address(plugin.getVotingToken());

        // New token
        votingToken = ERC20Mock(
            createProxyAndCall(
                address(votingTokenBase),
                abi.encodeWithSelector(ERC20Mock.initialize.selector)
            )
        );

        // Deploy a new plugin instance
        OptimisticTokenVotingPlugin.OptimisticGovernanceSettings
            memory settings = OptimisticTokenVotingPlugin
                .OptimisticGovernanceSettings({
                    minVetoRatio: uint32(RATIO_BASE / 10),
                    minDuration: 10 days,
                    minProposerVotingPower: 0
                });

        plugin = OptimisticTokenVotingPlugin(
            createProxyAndCall(
                address(pluginBase),
                abi.encodeWithSelector(
                    OptimisticTokenVotingPlugin.initialize.selector,
                    dao,
                    settings,
                    votingToken
                )
            )
        );

        assertEq(
            address(plugin.getVotingToken()),
            address(votingToken),
            "Incorrect voting token"
        );
        assertEq(
            address(votingToken) != oldToken,
            true,
            "The token address sould have changed"
        );
    }

    function test_TotalVotingPowerReturnsTheRightSupply() public {
        assertEq(
            plugin.totalVotingPower(block.number - 1),
            votingToken.getPastTotalSupply(block.number - 1),
            "Incorrect total voting power"
        );
        assertEq(
            plugin.totalVotingPower(block.number - 1),
            0 ether,
            "Incorrect total voting power"
        );

        // New token
        votingToken = ERC20Mock(
            createProxyAndCall(
                address(votingTokenBase),
                abi.encodeWithSelector(ERC20Mock.initialize.selector)
            )
        );
        votingToken.mint(alice, 10 ether);
        vm.roll(block.number + 1);

        // Deploy a new plugin instance
        OptimisticTokenVotingPlugin.OptimisticGovernanceSettings
            memory settings = OptimisticTokenVotingPlugin
                .OptimisticGovernanceSettings({
                    minVetoRatio: uint32(RATIO_BASE / 10),
                    minDuration: 10 days,
                    minProposerVotingPower: 0
                });

        plugin = OptimisticTokenVotingPlugin(
            createProxyAndCall(
                address(pluginBase),
                abi.encodeWithSelector(
                    OptimisticTokenVotingPlugin.initialize.selector,
                    dao,
                    settings,
                    votingToken
                )
            )
        );

        assertEq(
            plugin.totalVotingPower(block.number - 1),
            votingToken.getPastTotalSupply(block.number - 1),
            "Incorrect total voting power"
        );
        assertEq(
            plugin.totalVotingPower(block.number - 1),
            10 ether,
            "Incorrect total voting power"
        );
    }

    function test_MinVetoRatioReturnsTheRightValue() public {
        assertEq(
            plugin.minVetoRatio(),
            uint32(RATIO_BASE / 10),
            "Incorrect minVetoRatio"
        );

        // New plugin instance
        OptimisticTokenVotingPlugin.OptimisticGovernanceSettings
            memory settings = OptimisticTokenVotingPlugin
                .OptimisticGovernanceSettings({
                    minVetoRatio: uint32(RATIO_BASE / 5),
                    minDuration: 10 days,
                    minProposerVotingPower: 0
                });

        plugin = OptimisticTokenVotingPlugin(
            createProxyAndCall(
                address(pluginBase),
                abi.encodeWithSelector(
                    OptimisticTokenVotingPlugin.initialize.selector,
                    dao,
                    settings,
                    votingToken
                )
            )
        );

        assertEq(
            plugin.minVetoRatio(),
            uint32(RATIO_BASE / 5),
            "Incorrect minVetoRatio"
        );
    }

    function test_MinDurationReturnsTheRightValue() public {
        assertEq(plugin.minDuration(), 10 days, "Incorrect minDuration");

        // New plugin instance
        OptimisticTokenVotingPlugin.OptimisticGovernanceSettings
            memory settings = OptimisticTokenVotingPlugin
                .OptimisticGovernanceSettings({
                    minVetoRatio: uint32(RATIO_BASE / 5),
                    minDuration: 25 days,
                    minProposerVotingPower: 0
                });

        plugin = OptimisticTokenVotingPlugin(
            createProxyAndCall(
                address(pluginBase),
                abi.encodeWithSelector(
                    OptimisticTokenVotingPlugin.initialize.selector,
                    dao,
                    settings,
                    votingToken
                )
            )
        );

        assertEq(plugin.minDuration(), 25 days, "Incorrect minDuration");
    }

    function test_MinProposerVotingPowerReturnsTheRightValue() public {
        assertEq(
            plugin.minProposerVotingPower(),
            0,
            "Incorrect minProposerVotingPower"
        );

        // New token
        votingToken = ERC20Mock(
            createProxyAndCall(
                address(votingTokenBase),
                abi.encodeWithSelector(ERC20Mock.initialize.selector)
            )
        );
        votingToken.mint(alice, 10 ether);
        vm.roll(block.number + 1);

        // Deploy a new plugin instance
        OptimisticTokenVotingPlugin.OptimisticGovernanceSettings
            memory settings = OptimisticTokenVotingPlugin
                .OptimisticGovernanceSettings({
                    minVetoRatio: uint32(RATIO_BASE / 10),
                    minDuration: 10 days,
                    minProposerVotingPower: 1 ether
                });

        plugin = OptimisticTokenVotingPlugin(
            createProxyAndCall(
                address(pluginBase),
                abi.encodeWithSelector(
                    OptimisticTokenVotingPlugin.initialize.selector,
                    dao,
                    settings,
                    votingToken
                )
            )
        );

        assertEq(
            plugin.minProposerVotingPower(),
            1 ether,
            "Incorrect minProposerVotingPower"
        );
    }

    function test_TokenHoldersAreMembers() public {
        assertEq(plugin.isMember(alice), false, "Alice should not be a member");
        assertEq(plugin.isMember(bob), false, "Bob should not be a member");
        assertEq(
            plugin.isMember(randomWallet),
            false,
            "Random wallet should not be a member"
        );

        // New token
        votingToken = ERC20Mock(
            createProxyAndCall(
                address(votingTokenBase),
                abi.encodeWithSelector(ERC20Mock.initialize.selector)
            )
        );
        votingToken.mint(alice, 10 ether);
        votingToken.mint(bob, 5 ether);
        vm.roll(block.number + 1);

        // Deploy a new plugin instance
        OptimisticTokenVotingPlugin.OptimisticGovernanceSettings
            memory settings = OptimisticTokenVotingPlugin
                .OptimisticGovernanceSettings({
                    minVetoRatio: uint32(RATIO_BASE / 10),
                    minDuration: 10 days,
                    minProposerVotingPower: 1 ether
                });

        plugin = OptimisticTokenVotingPlugin(
            createProxyAndCall(
                address(pluginBase),
                abi.encodeWithSelector(
                    OptimisticTokenVotingPlugin.initialize.selector,
                    dao,
                    settings,
                    votingToken
                )
            )
        );

        assertEq(plugin.isMember(alice), true, "Alice should be a member");
        assertEq(plugin.isMember(bob), true, "Bob should be a member");
        assertEq(
            plugin.isMember(randomWallet),
            false,
            "Random wallet should not be a member"
        );
    }

    function test_CreateProposalRevertsWhenCalledByANonProposer() public {
        revert Unimplemented();
    }

    function test_CreateProposalSucceedsWhenMinimumVotingPowerIsZero() public {
        revert Unimplemented();
    }

    function test_CreateProposalRevertsWhenTheCallerOwnsLessThanTheMinimumVotingPower()
        public
    {
        revert Unimplemented();
    }

    function test_CreateProposalRevertsIfThereIsNoVotingPower() public {
        revert Unimplemented();
    }

    function test_CreateProposalRevertsIfTheStartDateIsAfterTheEndDate()
        public
    {
        revert Unimplemented();
    }

    function test_CreateProposalRevertsIfTheStartDateIsInThePast() public {
        revert Unimplemented();
    }

    function test_CreateProposalStartsNowWhenStartDateIsZero() public {
        revert Unimplemented();
    }

    function test_CreateProposalEndsAfterTheMinDurationWhenEndDateIsZero()
        public
    {
        revert Unimplemented();
    }

    function test_CreateProposalUsesTheCurrentMinVetoRatio() public {
        revert Unimplemented();
    }

    function test_CreateProposalReturnsTheProposalId() public {
        revert Unimplemented();
    }

    function test_CreateProposalEmitsAnEvent() public {
        revert Unimplemented();
    }

    function test_HasVetoedReturnsTheRightValue() public {
        revert Unimplemented();
    }

    function test_CanVetoReturnsFalseWhenAProposalDoesntExist() public {
        revert Unimplemented();
    }

    function test_CanVetoReturnsFalseWhenAProposalHasNotStarted() public {
        revert Unimplemented();
    }

    function test_CanVetoReturnsFalseWhenAVoterAlreadyVetoed() public {
        revert Unimplemented();
    }

    function test_CanVetoReturnsFalseWhenAnAddressHasNoVotingPower() public {
        revert Unimplemented();
    }

    function test_CanVetoReturnsTrueOtherwise() public {
        revert Unimplemented();
    }

    function test_CanExecuteReturnsFalseWhenAlreadyExecuted() public {
        revert Unimplemented();
    }

    function test_CanExecuteReturnsFalseWhenStillOngoing() public {
        revert Unimplemented();
    }

    function test_CanExecuteReturnsFalseWhenEnoughVetoesAreRegistered() public {
        revert Unimplemented();
    }

    function test_CanExecuteReturnsTrueOtherwise() public {
        revert Unimplemented();
    }

    function test_IsMinVetoRatioReachedReturnsFalseWhenNotEnoughPeopleHaveVetoed()
        public
    {
        revert Unimplemented();
    }

    function test_IsMinVetoRatioReachedReturnsTrueWhenEnoughPeopleHaveVetoed()
        public
    {
        revert Unimplemented();
    }

    function test_GetProposalReturnsTheRightValues() public {
        revert Unimplemented();
    }

    function test_VetoRevertsWhenTheProposalDoesntExist() public {
        revert Unimplemented();
    }

    function test_VetoRevertsWhenTheProposalHasNotStarted() public {
        revert Unimplemented();
    }

    function test_VetoRevertsWhenNotATokenHolder() public {
        revert Unimplemented();
    }

    function test_VetoRevertsWhenAlreadyVetoed() public {
        revert Unimplemented();
    }

    function test_VetoRegistersAVetoForTheTokenHolderAndIncreasesTheTally()
        public
    {
        revert Unimplemented();
    }

    function test_VetoEmitsAnEvent() public {
        revert Unimplemented();
    }

    function test_ExecuteRevertsWhenAlreadyExecuted() public {
        revert Unimplemented();
    }

    function test_ExecuteRevertsWhenStillOngoing() public {
        revert Unimplemented();
    }

    function test_ExecuteRevertsWhenEnoughVetoesAreRegistered() public {
        revert Unimplemented();
    }

    function testFuzz_ExecuteExecutesTheProposalActionsWhenNonDefeated(
        uint256 _tokenSupply
    ) public {
        revert Unimplemented();
    }

    function test_ExecuteMarksTheProposalAsExecuted() public {
        revert Unimplemented();
    }

    function test_ExecuteEmitsAnEvent() public {
        revert Unimplemented();
    }

    function test_UpdateOptimisticGovernanceSettingsRevertsWhenNoPermission()
        public
    {
        revert Unimplemented();
    }

    function test_UpdateOptimisticGovernanceSettingsRevertsWhenTheMinVetoRatioIsZero()
        public
    {
        revert Unimplemented();
    }

    function test_UpdateOptimisticGovernanceSettingsRevertsWhenTheMinVetoRatioIsAboveTheMaximum()
        public
    {
        revert Unimplemented();
    }

    function test_UpdateOptimisticGovernanceSettingsRevertsWhenTheMinDurationIsLessThanFourDays()
        public
    {
        revert Unimplemented();
    }

    function test_UpdateOptimisticGovernanceSettingsRevertsWhenTheMinDurationIsMoreThanOneYear()
        public
    {
        revert Unimplemented();
    }

    function test_UpdateOptimisticGovernanceSettingsRevertsWhenMinProposerVotingPowerIsMoreThanTheTokenSupply()
        public
    {
        revert Unimplemented();
    }

    function test_UpdateOptimisticGovernanceSettingsEmitsAnEventWhenSuccessful()
        public
    {
        revert Unimplemented();
    }

    function test_UpgradeToRevertsWhenCalledFromNonUpgrader() public {
        revert Unimplemented();
    }

    function test_UpgradeToAndCallRevertsWhenCalledFromNonUpgrader() public {
        revert Unimplemented();
    }

    function test_UpgradeToSucceedsWhenCalledFromUpgrader() public {
        revert Unimplemented();
    }

    function test_UpgradeToAndCallSucceedsWhenCalledFromUpgrader() public {
        revert Unimplemented();
    }

    // HELPERS
    function createProxyAndCall(
        address _logic,
        bytes memory _data
    ) private returns (address) {
        return address(new ERC1967Proxy(_logic, _data));
    }
}
