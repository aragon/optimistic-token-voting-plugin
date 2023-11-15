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
import {DaoUnauthorized} from "@aragon/osx/core/utils/auth.sol";
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
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed creator,
        uint64 startDate,
        uint64 endDate,
        bytes metadata,
        IDAO.Action[] actions,
        uint256 allowFailureMap
    );

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
            10 ether,
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
            10 ether,
            "Incorrect total voting power"
        );

        // New token
        votingToken = ERC20Mock(
            createProxyAndCall(
                address(votingTokenBase),
                abi.encodeWithSelector(ERC20Mock.initialize.selector)
            )
        );
        votingToken.mint(alice, 15 ether);
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
            15 ether,
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
        assertEq(plugin.isMember(alice), true, "Alice should not be a member");
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
        vm.stopPrank();
        vm.startPrank(bob);
        IDAO.Action[] memory actions = new IDAO.Action[](0);
        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(plugin),
                bob,
                plugin.PROPOSER_PERMISSION_ID()
            )
        );
        plugin.createProposal("", actions, 0, 0, 0);

        vm.stopPrank();
        vm.startPrank(alice);

        plugin.createProposal("", actions, 0, 0, 0);
    }

    function test_CreateProposalSucceedsWhenMinimumVotingPowerIsZero() public {
        // Bob can create proposals on the plugin now
        dao.grant(address(plugin), bob, plugin.PROPOSER_PERMISSION_ID());

        vm.stopPrank();
        vm.startPrank(bob);

        IDAO.Action[] memory actions = new IDAO.Action[](0);
        uint256 proposalId = plugin.createProposal("", actions, 0, 0, 0);
        assertEq(proposalId, 0);
        proposalId = plugin.createProposal("", actions, 0, 0, 0);
        assertEq(proposalId, 1);
    }

    function test_CreateProposalRevertsWhenTheCallerOwnsLessThanTheMinimumVotingPower()
        public
    {
        vm.stopPrank();
        vm.startPrank(alice);

        IDAO.Action[] memory actions = new IDAO.Action[](0);
        OptimisticTokenVotingPlugin.OptimisticGovernanceSettings
            memory newSettings = OptimisticTokenVotingPlugin
                .OptimisticGovernanceSettings({
                    minVetoRatio: uint32(RATIO_BASE / 10),
                    minDuration: 10 days,
                    minProposerVotingPower: 5 ether
                });
        dao.grant(address(plugin), bob, plugin.PROPOSER_PERMISSION_ID());
        dao.grant(
            address(plugin),
            alice,
            plugin.UPDATE_OPTIMISTIC_GOVERNANCE_SETTINGS_PERMISSION_ID()
        );
        plugin.updateOptimisticGovernanceSettings(newSettings);

        vm.stopPrank();
        vm.startPrank(bob);

        // Bob holds no tokens
        vm.expectRevert(
            abi.encodeWithSelector(
                OptimisticTokenVotingPlugin.ProposalCreationForbidden.selector,
                bob
            )
        );
        plugin.createProposal("", actions, 0, 0, 0);
    }

    function test_CreateProposalRevertsIfThereIsNoVotingPower() public {
        vm.stopPrank();
        vm.startPrank(alice);

        // Deploy ERC20 token (0 supply)
        votingToken = ERC20Mock(
            createProxyAndCall(
                address(votingTokenBase),
                abi.encodeWithSelector(ERC20Mock.initialize.selector)
            )
        );

        // Deploy a new plugin instance
        IDAO.Action[] memory actions = new IDAO.Action[](0);
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
        dao.grant(address(plugin), alice, plugin.PROPOSER_PERMISSION_ID());

        // Try to create
        vm.expectRevert(
            abi.encodeWithSelector(
                OptimisticTokenVotingPlugin.NoVotingPower.selector
            )
        );
        plugin.createProposal("", actions, 0, 0, 0);
    }

    function test_CreateProposalRevertsIfTheStartDateIsAfterTheEndDate()
        public
    {
        IDAO.Action[] memory actions = new IDAO.Action[](0);
        uint32 startDate = 200000;
        uint32 endDate = 10;
        vm.expectRevert(
            abi.encodeWithSelector(
                OptimisticTokenVotingPlugin.DateOutOfBounds.selector,
                startDate + 10 days,
                endDate
            )
        );
        plugin.createProposal("", actions, 0, startDate, endDate);
    }

    function test_CreateProposalRevertsIfStartDateIsInThePast() public {
        vm.warp(10); // timestamp = 10

        IDAO.Action[] memory actions = new IDAO.Action[](0);
        vm.expectRevert(
            abi.encodeWithSelector(
                OptimisticTokenVotingPlugin.DateOutOfBounds.selector,
                block.timestamp,
                1
            )
        );
        uint32 startDate = 1;
        plugin.createProposal("", actions, 0, startDate, startDate + 10 days);
    }

    function test_CreateProposalRevertsIfEndDateIsEarlierThanMinDuration()
        public
    {
        vm.warp(500); // timestamp = 500

        IDAO.Action[] memory actions = new IDAO.Action[](0);
        uint32 startDate = 1000;
        vm.expectRevert(
            abi.encodeWithSelector(
                OptimisticTokenVotingPlugin.DateOutOfBounds.selector,
                startDate + 10 days,
                startDate + 10 minutes
            )
        );
        plugin.createProposal(
            "",
            actions,
            0,
            startDate,
            startDate + 10 minutes
        );
    }

    function test_CreateProposalStartsNowWhenStartDateIsZero() public {
        vm.warp(500);

        IDAO.Action[] memory actions = new IDAO.Action[](0);
        uint32 startDate = 0;
        uint256 proposalId = plugin.createProposal(
            "",
            actions,
            0,
            startDate,
            0
        );

        (
            ,
            ,
            OptimisticTokenVotingPlugin.ProposalParameters memory parameters,
            ,
            ,

        ) = plugin.getProposal(proposalId);
        assertEq(500, parameters.startDate, "Incorrect startDate");
    }

    function test_CreateProposalEndsAfterMinDurationWhenEndDateIsZero() public {
        vm.warp(500);

        IDAO.Action[] memory actions = new IDAO.Action[](0);
        uint32 startDate = 0;
        uint32 endDate = 0;
        uint256 proposalId = plugin.createProposal(
            "",
            actions,
            0,
            startDate,
            endDate
        );

        (
            ,
            ,
            OptimisticTokenVotingPlugin.ProposalParameters memory parameters,
            ,
            ,

        ) = plugin.getProposal(proposalId);
        assertEq(500 + 10 days, parameters.endDate, "Incorrect endDate");
    }

    function test_CreateProposalUsesTheCurrentMinVetoRatio() public {
        IDAO.Action[] memory actions = new IDAO.Action[](0);
        uint256 proposalId = plugin.createProposal("", actions, 0, 0, 0);

        (
            ,
            ,
            OptimisticTokenVotingPlugin.ProposalParameters memory parameters,
            ,
            ,

        ) = plugin.getProposal(proposalId);
        assertEq(
            parameters.minVetoVotingPower,
            1 ether,
            "Incorrect minVetoVotingPower"
        );

        // Now with a different value
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

        dao.grant(address(plugin), alice, plugin.PROPOSER_PERMISSION_ID());
        proposalId = plugin.createProposal("", actions, 0, 0, 0);
        (, , parameters, , , ) = plugin.getProposal(proposalId);
        assertEq(
            parameters.minVetoVotingPower,
            2 ether,
            "Incorrect minVetoVotingPower"
        );
    }

    function test_CreateProposalReturnsTheProposalId() public {
        IDAO.Action[] memory actions = new IDAO.Action[](0);
        uint256 proposalId = plugin.createProposal("", actions, 0, 0, 0);
        assertEq(proposalId == 0, true, "Should have created proposal 0");

        proposalId = plugin.createProposal("", actions, 0, 0, 0);
        assertEq(proposalId == 1, true, "Should have created proposal 1");
    }

    function test_CreateProposalEmitsAnEvent() public {
        IDAO.Action[] memory actions = new IDAO.Action[](0);
        vm.expectEmit();
        emit ProposalCreated(
            0,
            alice,
            uint64(block.timestamp),
            uint64(block.timestamp + 10 days),
            "",
            actions,
            0
        );
        plugin.createProposal("", actions, 0, 0, 0);
    }

    function test_GetProposalReturnsTheRightValues() public {
        vm.warp(500);
        uint32 startDate = 600;
        uint32 endDate = startDate + 15 days;

        IDAO.Action[] memory actions = new IDAO.Action[](1);
        actions[0].to = address(plugin);
        actions[0].value = 1 wei;
        actions[0].data = abi.encodeWithSelector(
            OptimisticTokenVotingPlugin.totalVotingPower.selector,
            0
        );
        uint256 failSafeBitmap = 1;

        uint256 proposalId = plugin.createProposal(
            "ipfs://",
            actions,
            failSafeBitmap,
            startDate,
            endDate
        );

        (bool open0, , , , , ) = plugin.getProposal(proposalId);
        assertEq(open0, false, "The proposal should not be open");

        // Move on
        vm.warp(startDate);

        (
            bool open,
            bool executed,
            OptimisticTokenVotingPlugin.ProposalParameters memory parameters,
            uint256 vetoTally,
            IDAO.Action[] memory actualActions,
            uint256 actualFailSafeBitmap
        ) = plugin.getProposal(proposalId);

        assertEq(open, true, "The proposal should be open");
        assertEq(executed, false, "The proposal should not be executed");
        assertEq(parameters.startDate, startDate, "Incorrect startDate");
        assertEq(parameters.endDate, endDate, "Incorrect endDate");
        assertEq(parameters.snapshotBlock, 1, "Incorrect snapshotBlock");
        assertEq(
            parameters.minVetoVotingPower,
            plugin.totalVotingPower(block.number - 1) / 10,
            "Incorrect minVetoVotingPower"
        );
        assertEq(vetoTally, 0, "The tally should be zero");
        assertEq(actualActions.length, 1, "Actions should have one item");
        assertEq(
            actualFailSafeBitmap,
            failSafeBitmap,
            "Incorrect failsafe bitmap"
        );

        // Move on
        vm.warp(endDate);

        (bool open1, , , , , ) = plugin.getProposal(proposalId);
        assertEq(open1, false, "The proposal should not be open anymore");
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

    function test_HasVetoedReturnsTheRightValue() public {
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
