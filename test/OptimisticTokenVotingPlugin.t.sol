// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {OptimisticTokenVotingPlugin} from "../src/OptimisticTokenVotingPlugin.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {RATIO_BASE} from "@aragon/osx/plugins/utils/Ratio.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract OptimisticTokenVotingPluginTest is Test {
    address immutable daoBase = address(new DAO());
    address immutable pluginBase = address(new OptimisticTokenVotingPlugin());
    address immutable votingTokenBase = address(new ERC20Mock());

    DAO public dao;
    OptimisticTokenVotingPlugin public plugin;
    ERC20Mock votingToken;

    address alice = address(0xa11ce);
    address bob = address(0xB0B);
    address randomUser = vm.addr(1234567890);

    error Unimplemented();

    function setUp() public {
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

        vm.roll(block.number + 1);

        // Deploy a new plugin instance
        OptimisticTokenVotingPlugin.OptimisticGovernanceSettings
            memory settings = OptimisticTokenVotingPlugin
                .OptimisticGovernanceSettings({
                    minVetoRatio: uint32(RATIO_BASE / 10),
                    minDuration: 10 days,
                    minProposerVotingPower: 0 ether
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

    function test_InitializeRevertsIfInitializing() public {
        revert Unimplemented();
    }

    function test_InitializeSetsTheProperValues() public {
        revert Unimplemented();
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
        revert Unimplemented();
    }

    function test_SupportsInterfaceReturnsTrueForOptimisticGovernance() public {
        revert Unimplemented();
    }

    function test_SupportsInterfaceReturnsTrueForIOptimisticTokenVoting()
        public
    {
        revert Unimplemented();
    }

    function test_SupportsInterfaceReturnsTrueForIMembership() public {
        revert Unimplemented();
    }

    function test_SupportsInterfaceReturnsTrueForIProposal() public {
        revert Unimplemented();
    }

    function test_SupportsInterfaceReturnsTrueForIERC165Upgradeable() public {
        revert Unimplemented();
    }

    function test_SupportsInterfaceReturnsFalseOtherwise() public {
        revert Unimplemented();
    }

    function test_GetVotingTokenReturnsTheRightAddress() public {
        revert Unimplemented();
    }

    function test_TotalVotingPowerReturnsTheRightSupply() public {
        revert Unimplemented();
    }

    function test_MinVetoRatioReturnsTheRightValue() public {
        revert Unimplemented();
    }

    function test_MinDurationReturnsTheRightValue() public {
        revert Unimplemented();
    }

    function test_MinProposerVotingPowerReturnsTheRightValue() public {
        revert Unimplemented();
    }

    function test_TokenHoldersAreMembers() public {
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
