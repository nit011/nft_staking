## Staking NFTs:

- The user calls stakeNFT with an array of NFT IDs.
- The contract checks if the user owns these NFTs.
- The NFTs are transferred to the contract, and the staking details are recorded.
- The Staked event is emitted.

## Unstaking NFTs:

- The user calls unstakeNFT with an array of NFT IDs.
- The contract checks if the NFTs are already in the unbonding process.
- The unbonding process is initiated, and the Unstaked event is emitted.

## Withdrawing NFTs:

- After the unbonding period is over, the user calls withdrawNFT with an NFT ID.
- The contract checks if the unbonding period has passed.
- The NFT is transferred back to the user, and the staking details are removed.

## Claiming Rewards:

- The user calls claimRewards.
- The contract checks if the reward delay period has passed since the last claim.
- The total rewards are calculated, and the reward tokens are transferred to the user.
- The Claimed event is emitted.

## Notes

- In this contract i use the IERC721Enumerable interface to access the tokenOfOwnerByIndex function, which allows iterating through all NFTs owned by a user.
- This contract is upgradeable using OpenZeppelin's UUPS (Universal Upgradeable Proxy Standard) pattern.
- This  contract uses OpenZeppelin's Pausable, Ownable, and ReentrancyGuard libraries to provide additional security and administrative functionalities.


## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

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
