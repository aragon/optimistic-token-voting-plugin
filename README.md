# Optimistic token voting plugin for OSx

Aragon OSx plugin, implementing an optimistic governance model where token holders can veto proposals. Non-vetoed proposals can be executed by anyone. Proposals can be created by a restricted list of addresses, typically a sub DAO or a multisig. 

## Overview

The [DAO](https://github.com/aragon/osx/blob/develop/packages/contracts/src/core/dao/DAO.sol) contract holds all the assets and rights, while plugins are custom, opt-in pieces of logic that can perform certain actions governed by the DAO's permission database.

The DAO contract can be deployed by using Aragon's DAOFactory contract. This will deploy a new DAO with the desired plugins and settings.

## How permissions work

An Aragon DAO is a set of permissions that are used to restrict who can do what and where.

A permission looks like:

- An address `who` holds `MY_PERMISSION_ID` on a target contract `where`

Brand new DAO's are deployed with a `ROOT_PERMISSION` assigned to its creator, but the DAO will typically deployed by the DAO factory, which will install all the requested plugins and drop the ROOT permission after the set up is done.

Managing permissions is made via two functions that are called on the DAO:

```solidity
function grant(address _where, address _who, bytes32 _permissionId);

function revoke(address _where, address _who, bytes32 _permissionId);
```

### Permission Conditions

For the cases where an unrestricted permission is not derisable, a [Permission Condition](https://devs.aragon.org/docs/osx/how-it-works/core/permissions/conditions) can be used.

Conditional permissions look like this:

- An address `who` holds `MY_PERMISSION_ID` on a target contract `where`, only `when` the condition contract approves it

Conditional permissions are granted like this:

```solidity
function grantWithCondition(
  address _where,
  address _who,
  bytes32 _permissionId,
  IPermissionCondition _condition
);
```

See the condition contract boilerplate. It provides the plumbing to easily restrict what the different multisig plugins can propose on the OptimisticVotingPlugin.

[Learn more about OSx permissions](https://devs.aragon.org/docs/osx/how-it-works/core/permissions/)

### Permissions being used

Below are all the permissions that a [PluginSetup](#plugin-setup-contracts) contract may want to request:

- `EXECUTE_PERMISSION` is required to make the DAO `execute` a set of actions
  - Only governance plugins should have this permission
- `ROOT_PERMISSION` is required to make the DAO `grant` or `revoke` permissions
  - The DAO needs to be ROOT on itself (it is by default)
  - Nobody else should be ROOT on the DAO
- `UPGRADE_PLUGIN_PERMISSION` is required for an address to be able to upgrade a plugin to a newer version published by the developer
  - Typically called by the DAO via proposal
  - Optionally granted to an additional address for convenience
- `PROPOSER_PERMISSION_ID` is required to be able to create optimistic proposals on the governance plugin

Other DAO specific permissions:

- `UPGRADE_DAO_PERMISSION`
- `SET_METADATA_PERMISSION`
- `SET_TRUSTED_FORWARDER_PERMISSION`
- `SET_SIGNATURE_VALIDATOR_PERMISSION`
- `REGISTER_STANDARD_CALLBACK_PERMISSION`

## Interacting with the contracts from JS

Run `yarn build && yarn typechain` on the `packages/contracts` folder.

See `packages/contracts/typechain` for all the generated JS/TS wrappers to interact with the contracts.

[Learn more](https://github.com/dethcrypto/TypeChain)

## Encoding and decoding actions

Making calls to the DAO is straightforward, however making execute arbitrary actions requires them to be encoded, stored on chain and be approved before they can be executed.

To this end, the DAO has a struct called `Action { to, value, data }`, which will make the DAO call the `to` address, with `value` ether and call the given calldata (if any). To encode these functions, you can make use of the provided [JS client template](packages/js-client/src).

It uses the generated typechain artifacts, which contain the interfaces for the available contract methods and allow to easily encode function calls into hex strings.

See [packages/js-client/src/internal/modules/encoding.ts](packages/js-client/src/internal/modules/encoding.ts) and [decoding.ts](packages/js-client/src/internal/modules/decoding.ts) for a JS boilerplate.

## The DAO's plugins

### Optimistic Token Voting plugin

It's the main governance plugin for standard spaces, where all proposals can be vetoed by token holders. It is a adapted version of Aragon's [TokenVoting plugin](https://github.com/aragon/osx/blob/develop/packages/contracts/src/plugins/governance/majority-voting/token/TokenVoting.sol). Only addresses holding the `PROPOSER_PERMISSION_ID` can create proposals and they can only be executed after a majority against hasn't emerged after a given period of time.

The governance settings need to be defined when the plugin is deployed but the DAO can change them at any time. Proposal creators can cancel their own proposals before they end.

#### Methods

TO DO

Inherited:

- `function vote(uint256 _proposalId, VoteOption _voteOption, bool _tryEarlyExecution)`
- `function execute(uint256 _proposalId)`
- `function updateVotingSettings(VotingSettings calldata _votingSettings)`
- `function upgradeTo(address newImplementation)`
- `function upgradeToAndCall(address newImplementation, bytes data)`

#### Getters

TO DO
- `function supportsInterface(bytes4 _interfaceId) returns (bool)`

Inherited:

- `function canVote(uint256 _proposalId, address _voter, VoteOption _voteOption)`
- `function getProposal(uint256 _proposalId) returns (bool open, bool executed, ProposalParameters parameters, Tally tally, IDAO.Action[] actions, uint256 allowFailureMap)`
- `function getVoteOption(uint256 _proposalId, address _voter)`
- `function isSupportThresholdReached(uint256 _proposalId) returns (bool)`
- `function isSupportThresholdReachedEarly(uint256 _proposalId)`
- `function isMinParticipationReached(uint256 _proposalId) returns (bool)`
- `function canExecute(uint256 _proposalId) returns (bool)`
- `function supportThreshold() returns (uint32)`
- `function minParticipation() returns (uint32)`
- `function minDuration() returns (uint64)`
- `function minProposerVotingPower() returns (uint256)`
- `function votingMode() returns (VotingMode)`
- `function totalVotingPower(uint256 _blockNumber) returns (uint256)`
- `function implementation() returns (address)`

#### Events

- `event ProposalCanceled(uint256 proposalId)`

Inherited:

- `event ProposalCreated(uint256 indexed proposalId, address indexed creator, uint64 startDate, uint64 endDate, bytes metadata, IDAO.Action[] actions, uint256 allowFailureMap)`
- `event VoteCast(uint256 indexed proposalId, address indexed voter, VoteOption voteOption, uint256 votingPower)`
- `event ProposalExecuted(uint256 indexed proposalId)`
- `event VotingSettingsUpdated(VotingMode votingMode, uint32 supportThreshold, uint32 minParticipation, uint64 minDuration, uint256 minProposerVotingPower)`

#### Permissions

- Proposers create proposals
- The plugin can execute on the DAO
- The DAO can update the plugin settings
- The DAO can upgrade the plugin

## Plugin Setup contracts

So far, we have been talking about the plugin contracts. However, they need to be prepared and installed on a DAO and for this, a DAO needs to approve for it. To this end, PluginSetup contracts act as an install script in charge of preparing installations, updates and uninstallations. They always have two steps:

1. An unprivileged step to prepare the plugin and request any privileged changes
2. An approval step after which, editors execute an action that applies the requested installation, upgrade or uninstallation

[Learn more](https://devs.aragon.org/docs/osx/how-to-guides/plugin-development/upgradeable-plugin/setup)

### Installing plugins when deploying the DAO

This is taken care by the `DAOFactory`. The DAO creator calls `daoFactory.createDao()`:

- The call contains:
  - The DAO settings
  - An array with the details and the settings of the desired plugins
- The method will deploy a new DAO and set itself as ROOT
- It will then call `prepareInstallation()` on all plugins and `applyInstallation()` right away
- It will finally drop `ROOT_PERMISSION` on itself

[See a JS example of installing plugins during a DAO's deployment](https://devs.aragon.org/docs/sdk/examples/client/create-dao#create-a-dao)

### Installing plugins afterwards

Plugin changes need a proposal to be passed when the DAO already exists.

1. Calling `pluginSetup.prepareInstallation()`
   - A new plugin instance is deployed with the desired settings
   - The call requests a set of permissions to be applied by the DAO
2. Editors pass a proposal to make the DAO call `applyInstallation()` on the [PluginSetupProcessor](https://devs.aragon.org/docs/osx/how-it-works/framework/plugin-management/plugin-setup/)
   - This applies the requested permissions and the plugin becomes installed

See `OptimistictokenVotingPluginSetup`.

[Learn more about plugin setup's](https://devs.aragon.org/docs/osx/how-it-works/framework/plugin-management/plugin-setup/) and [preparing installations](https://devs.aragon.org/docs/sdk/examples/client/prepare-installation).

## Deploying a DAO

The recommended way to create a DAO is by using `@aragon/sdk-client`. It uses the `DAOFactory` under the hood and it reduces the amount of low level interactions with the protocol.

[See an example](https://devs.aragon.org/docs/sdk/examples/client/create-dao).

In the example, the code is making use of the existing JS client for [Aragon's Token Voting plugin](https://github.com/aragon/sdk/tree/develop/modules/client/src/tokenVoting). They encapsulate all the Typechain and Subgraph calls and provide a high level library.

It is **recommended** to use the provided boilerplate on `packages/js-client` and adapt the existing Aragon's TokenVoting plugin to make use of the `MainVotingPlugin__factory` class.

## Plugin deployment

- The HardHat deployment scripts are located on the `packages/contracts/deploy` folder.
- The settings about the naming, ID's and versions can be found on `packages/contracts/plugin-setup-params.ts`.
- The deployments made will populate data to the `packages/contracts/plugin-repo-info.json` and `packages/contracts/plugin-repo-info-dev.json`.
- You need to copy `.env.template` into `.env` and provide your Infura API key

### Plugin metadata

Plugins need some basic metadata in order for JS clients to be able to handle installations and updates. Beyond a simple title and description, every contract's build metadata contains the ABI of the parameters that need to be encoded in order to prepare the plugin installation.

Every plugin has an `initialize()` methos, which acts as the constructor for UUPS upgradeable contracts. This method will be passed its DAO's address, as well as a `bytes memory data` parameter, with all the settings encoded.

The format of these settings is defined in the `packages/contracts/src/*-build.metadata.json` file. See the `pluginSetup` > `prepareInstallation` section.

## DO's and DONT's

- Never grant `ROOT_PERMISSION` unless you are just trying things out
- Never uninstall all plugins, as this would brick your DAO
- Ensure that there is at least always one plugin with `EXECUTE_PERMISSION` on the DAO
- Ensure that the DAO is ROOT on itself
- Use the `_gap[]` variable for upgradeable plugins, as a way to reserve storage slots for future plugin implementations
  - Decrement the `_gap` number for every new variable you add in the future

## Plugin upgradeability

By default, only the DAO can upgrade plugins to newer versions. This requires passing a proposal. For the 3 upgradeable plugins, their plugin setup allows to pass an optional parameter to define a plugin upgrader address.

When a zero address is passed, only the DAO can call `upgradeTo()` and `upgradeToAndCall()`. When a non-zero address is passed, the desired address will be able to upgrade to whatever newer version the developer has published.

Every new version needs to be published to the plugin's repository.

[Learn more about plugin upgrades](https://devs.aragon.org/docs/osx/how-to-guides/plugin-development/upgradeable-plugin/updating-versions).

## Development

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
