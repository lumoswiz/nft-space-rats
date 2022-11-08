# Space Rats

**An NFT project inspired by a [BowTiedPickle](https://twitter.com/BowTiedPickle/status/1586082088746639361) post.**

## Setup

- Install [Foundry](https://github.com/foundry-rs/foundry).
- To run all tests, in command line enter:

```sh
forge test
```

- To run a specific test (with stack and setup traces displayed):

```sh
forge test --match-contract [CONTRACT_NAME] --match-test [TEST_NAME] -vvvvv
```

## Exercise Description

Problem specification from project brief:

- A genesis drop of 2000 Space Rat PFP NFts with 1000 mintable by whitelisted addresses and public addresses, respectively.
- Rats can be sent to work in asteroid mines to earn Iridium tokens and Geodes.
- Geodes can be cracked open to earn rewards, such as: whitelist spots, more Iridium tokens or spaceship keys.
- Spaceship art design to be finalised, but anticipate that spaceship keys will be used to unlock additional functional, such as: reward mining speed.

## Solution Outline

- [SpaceRats](./src/SpaceRats.sol) is an ERC721A contract. The collection size (public and whitelist slots) and a limit of maximum mints per address during mint is set in the constructor.
- [IridiumToken](./src/IridiumToken.sol) is an ERC20 contract with roles. Accounts with the `MINTER_ROLE` can mint new iridium tokens.
- [Geode](./src/Geode.sol) is an ERC1155 (mintable and burnable) contract with roles. Accounts with the `MINTER_ROLE` can mint new tokens with a tokenID set by a token counter and an amount of 1 (NFTs).
- [AsteroidMining](./src/staking/AsteroidMining.sol) is an optimistic NFT staking contract which is a [Bagholder](https://github.com/ZeframLou/bagholder) fork (written by [ZeframLou](https://twitter.com/boredGenius)). I have modified this contract to:
  - Accept SpaceRats NFTs and reward iridium tokens and geodes.
  - Incentives have a minimum staking (mining) time to earn geodes, tracked in `IncentiveInfo` structs.
  - Track address total mining times across incentives. At any point, if the user has no Space Rats staked, the mining time can be set back to zero. When claiming rewards, if the user mining time exceeds `miningTimeForGeodes`, the AsteroidMining contract will mint a geode as well as transferring iridium rewards to them.
- [ProcessingPlant](./src/ProcessingPlant.sol) is a contract that handles burning geodes and making Chainlink VRF V2 (Subscription Method) requests to obtain random numbers for determining user rewards. The contract works as follows:

  - The contract has process rounds (3 day periods) where users can deposit geodes to be cracked.
  - When the process round expires, the admin (SpaceRats multi sig) makes a VRF request for a number of random values equal to number of deposited geodes. Once fulfilled, the admin can call `crackGeodes` for the process round.
  - `crackGeodes` assigns random values to geode tokenIds, batch burns the deposited tokenIds then allocates rewards based on the random value of the tokenId. The base reward for cracking geodes is set by the admin to be `iridiumRewards` and there is a 1% chance to earn a whitelist spot for future expansion NFTS (tracked by `exercisableWhitelistSpots`).
  - Future expansion NFT projects (with the role: `WHITELIST_DECREMENT_ROLE`) can call `decrementExercisableWhitelistSpots` upon the user exercising their whitelist spot/s.

**Role Assignment:**

- Geode:

  - `MINTER_ROLE`: Asteroid Mining staking contract.
  - `BURNER_ROLE`: Processing Plant contract.

- Iridium:

  - `MINTER_ROLE`: Space Rats multi sig, Asteroid Mining staking contract and Processing Plant contract.

- Processing Plant:
  - `WHITELIST_DECREMENT_ROLE`: future expansion NFT projects.

## Testing

Unit tests:

- [SpaceRats](./test/SpaceRats.t.sol)
- [Iridium](./test/Iridium.t.sol)
- [Geode](./test/Geode.t.sol)
- [AsteroidMining](./test/AsteroidMining.t.sol)
- [ProcessingPlant](./test/ProcessingPlant.t.sol)

Project tests:

- [SpaceRatsProject](./test/SpaceRatsProject.t.sol)

## Acknowledgements

- [Bagholder](https://github.com/ZeframLou/bagholder) from ZeframLou.
